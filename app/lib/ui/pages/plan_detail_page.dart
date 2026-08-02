import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/plan.dart';
import '../../providers/plan_provider.dart';
import '../widgets/charts.dart';
import '../widgets/common_widgets.dart';
import '../widgets/workout_card.dart';

/// 计划详情：周视图（阶段色带 + 每周跑量柱状 + 该周课表列表）。
class PlanDetailPage extends StatefulWidget {
  final String planId;

  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  int _selectedWeek = 1;
  String? _markingWorkoutId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlanProvider>().loadDetail(widget.planId);
    });
  }

  /// 按周序号近似推导阶段（与 docs/04 周期化比例一致）
  String _phaseOfWeek(int weekNo, int totalWeeks) {
    final double pos = totalWeeks <= 1 ? 0 : (weekNo - 1) / (totalWeeks - 1);
    if (pos < 0.35) return 'base';
    if (pos < 0.65) return 'build';
    if (pos < 0.85) return 'peak';
    return 'taper';
  }

  Future<void> _mark(PlanWorkout workout, String status) async {
    setState(() => _markingWorkoutId = workout.id);
    final PlanProvider provider = context.read<PlanProvider>();
    final bool ok =
        await provider.markWorkout(widget.planId, workout.id, status);
    if (!mounted) return;
    setState(() => _markingWorkoutId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (status == 'done' ? '已标记完成 🎉' : '已跳过该课表')
            : (provider.detailError ?? '操作失败')),
      ),
    );
  }

  Future<void> _adapt() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在评估近 2 周完成度…')),
    );
    final String result =
        await context.read<PlanProvider>().adapt(widget.planId);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('计划自适应建议'),
        content: Text(result),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _archive() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('归档计划'),
        content: const Text('归档后不再显示在计划列表，确定继续？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    final bool ok =
        await context.read<PlanProvider>().archive(widget.planId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.read<PlanProvider>().error ?? '归档失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('计划详情'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'adapt') _adapt();
              if (v == 'archive') _archive();
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'adapt',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('自适应调整'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'archive',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('归档计划'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<PlanProvider>(
        builder: (BuildContext context, PlanProvider provider, _) {
          if (provider.detailLoading && provider.detail == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.detailError != null && provider.detail == null) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: '加载失败',
              message: provider.detailError,
              actionLabel: '重试',
              onAction: () =>
                  context.read<PlanProvider>().loadDetail(widget.planId),
            );
          }
          final PlanDetail? detail = provider.detail;
          if (detail == null) return const EmptyState(title: '计划不存在');

          final Map<int, double> weeklyKm = detail.weeklyKm();
          final int totalWeeks = detail.plan.weeks ??
              (weeklyKm.isEmpty
                  ? 1
                  : weeklyKm.keys.reduce((a, b) => a > b ? a : b));
          if (_selectedWeek > totalWeeks) _selectedWeek = totalWeeks;
          final List<PlanWorkout> weekWorkouts = detail.workouts
              .where((PlanWorkout w) => w.weekNo == _selectedWeek)
              .toList()
            ..sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));

          return RefreshIndicator(
            onRefresh: () =>
                context.read<PlanProvider>().loadDetail(widget.planId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _HeaderCard(detail: detail),
                const SectionHeader(title: '阶段与周跑量'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _PhaseStrip(
                          totalWeeks: totalWeeks,
                          phaseOfWeek: _phaseOfWeek,
                        ),
                        const SizedBox(height: 6),
                        const _PhaseLegend(),
                        const SizedBox(height: 12),
                        VolumeBarChart(
                          items: <VolumeBarItem>[
                            for (int w = 1; w <= totalWeeks; w++)
                              VolumeBarItem(
                                label: 'W$w',
                                value: weeklyKm[w] ?? 0,
                                color: phaseColor(
                                    _phaseOfWeek(w, totalWeeks)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionHeader(title: '每周课表'),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: totalWeeks,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int i) {
                      final int week = i + 1;
                      return ChoiceChip(
                        label: Text('第 $week 周'),
                        selected: _selectedWeek == week,
                        onSelected: (_) =>
                            setState(() => _selectedWeek = week),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (weekWorkouts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('该周暂无课表。'),
                    ),
                  )
                else
                  ...weekWorkouts.map(
                    (PlanWorkout w) => WorkoutCard(
                      workout: w,
                      marking: _markingWorkoutId == w.id,
                      onMarkDone: () => _mark(w, 'done'),
                      onMarkSkipped: () => _mark(w, 'skipped'),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final PlanDetail detail;

  const _HeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final TrainingPlan plan = detail.plan;
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(plan.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${raceTypeLabel(plan.raceType)}'
              '${plan.goalTimeSec != null ? ' · 目标 ${formatDuration(plan.goalTimeSec)}' : ''}'
              '${plan.vdot != null ? ' · VDOT ${plan.vdot!.toStringAsFixed(1)}' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.startDate ?? '--'} → ${plan.raceDate ?? '--'}'
              ' · 已完成 ${detail.doneCount}/${detail.workouts.length} 课',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseStrip extends StatelessWidget {
  final int totalWeeks;
  final String Function(int weekNo, int totalWeeks) phaseOfWeek;

  const _PhaseStrip({required this.totalWeeks, required this.phaseOfWeek});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(totalWeeks, (int i) {
        final int week = i + 1;
        return Expanded(
          child: Container(
            height: 10,
            margin: EdgeInsets.only(right: i < totalWeeks - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color: phaseColor(phaseOfWeek(week, totalWeeks)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _PhaseLegend extends StatelessWidget {
  const _PhaseLegend();

  @override
  Widget build(BuildContext context) {
    const List<String> phases = <String>['base', 'build', 'peak', 'taper'];
    return Wrap(
      spacing: 12,
      children: phases.map((String p) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: phaseColor(p),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(phaseLabel(p),
                style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      }).toList(),
    );
  }
}
