import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../widgets/charts.dart';
import '../widgets/common_widgets.dart';

/// 活动详情页（独立路由）
class ActivityDetailPage extends StatelessWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  Future<void> _delete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除活动'),
        content: const Text('删除后不可恢复，确定继续？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirm != true) return;
    final bool ok =
        await context.read<ActivitiesProvider>().deleteActivity(activityId);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.read<ActivitiesProvider>().error ?? '删除失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动详情'),
        actions: <Widget>[
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ActivityDetailView(activityId: activityId),
    );
  }
}

/// 活动详情内容（独立页 & 双栏右侧面板共用）
class ActivityDetailView extends StatefulWidget {
  final String activityId;

  const ActivityDetailView({super.key, required this.activityId});

  @override
  State<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends State<ActivityDetailView> {
  Activity? _activity;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ActivityDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Activity activity = await context
          .read<ActivitiesProvider>()
          .fetchDetail(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: '加载失败',
        message: _error,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    final Activity a = _activity!;
    final ActivityStreams? streams = a.streams;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  formatDateTime(a.startTime),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text(providerLabel(a.provider))),
            ],
          ),
          if (a.sourceFile != null)
            Text('来源文件：${a.sourceFile}',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 700
                  ? 4
                  : constraints.maxWidth >= 460
                      ? 3
                      : 2;
              final List<Widget> cards = <Widget>[
                StatCard(
                    title: '距离',
                    value: formatKm(a.distanceM),
                    unit: 'km',
                    icon: Icons.straighten),
                StatCard(
                    title: '时长',
                    value: formatDuration(a.durationSec),
                    icon: Icons.timer_outlined),
                StatCard(
                    title: '平均配速',
                    value: formatPace(a.avgPaceSecPerKm),
                    icon: Icons.speed,
                    color: AppColors.primary),
                if (a.avgHr != null)
                  StatCard(
                      title: '平均心率',
                      value: '${a.avgHr}',
                      unit: 'bpm',
                      icon: Icons.favorite,
                      color: AppColors.heartRed),
                if (a.maxHr != null)
                  StatCard(
                      title: '最大心率',
                      value: '${a.maxHr}',
                      unit: 'bpm',
                      icon: Icons.favorite_border,
                      color: AppColors.heartRed),
                if (a.avgCadence != null)
                  StatCard(
                      title: '步频',
                      value: '${a.avgCadence}',
                      unit: 'spm',
                      icon: Icons.directions_walk),
                if (a.elevationGainM != null)
                  StatCard(
                      title: '爬升',
                      value: a.elevationGainM!.toStringAsFixed(0),
                      unit: 'm',
                      icon: Icons.terrain),
                if (a.calories != null)
                  StatCard(
                      title: '热量',
                      value: '${a.calories}',
                      unit: 'kcal',
                      icon: Icons.local_fire_department,
                      color: AppColors.secondary),
                if (a.trainingEffect != null)
                  StatCard(
                      title: '训练效果',
                      value: a.trainingEffect!.toStringAsFixed(1),
                      icon: Icons.fitness_center),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.8,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 8),
          // 地图预留位（PRD：实时 GPS 不做，地图下一迭代）
          Card(
            child: SizedBox(
              height: 96,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.map_outlined,
                        color: Theme.of(context).disabledColor),
                    const SizedBox(height: 4),
                    Text('地图轨迹（预留，下一迭代）',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          if (streams != null && streams.pace.isNotEmpty) ...<Widget>[
            const SectionHeader(title: '配速曲线'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MetricLineChart(
                  values: streams.pace,
                  color: const Color(0xFF4A9DFF),
                  sampleSec: streams.sampleSec,
                  yLabel: (num v) => formatPace(v),
                ),
              ),
            ),
          ],
          if (streams != null && streams.hr.isNotEmpty) ...<Widget>[
            const SectionHeader(title: '心率曲线'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MetricLineChart(
                  values: streams.hr,
                  color: AppColors.heartRed,
                  sampleSec: streams.sampleSec,
                  yLabel: (num v) => v.round().toString(),
                ),
              ),
            ),
          ],
          if (a.laps.isNotEmpty) ...<Widget>[
            const SectionHeader(title: '圈速'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Table(
                  columnWidths: const <int, TableColumnWidth>{
                    0: IntrinsicColumnWidth(),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  children: <TableRow>[
                    _lapRow('圈', '距离', '时长', '配速', '心率',
                        header: true, context: context),
                    ...a.laps.map(
                      (ActivityLap lap) => _lapRow(
                        '${lap.lapNo}',
                        formatDistance(lap.distanceM),
                        formatDuration(lap.durationSec),
                        formatPace(lap.avgPaceSecPerKm),
                        lap.avgHr != null ? '${lap.avgHr}' : '--',
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  TableRow _lapRow(
    String no,
    String distance,
    String duration,
    String pace,
    String hr, {
    bool header = false,
    required BuildContext context,
  }) {
    final TextStyle? style = header
        ? Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall;
    Widget cell(String text, {bool pad = true}) => Padding(
          padding: EdgeInsets.symmetric(
              horizontal: pad ? 10 : 4, vertical: 6),
          child: Text(text, style: style),
        );
    return TableRow(
      children: <Widget>[
        cell(no, pad: false),
        cell(distance),
        cell(duration),
        cell(pace),
        cell(hr),
      ],
    );
  }
}
