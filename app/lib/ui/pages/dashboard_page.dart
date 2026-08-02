import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/stats.dart';
import '../../providers/stats_provider.dart';
import '../widgets/activity_tile.dart';
import '../widgets/charts.dart';
import '../widgets/common_widgets.dart';
import '../widgets/workout_card.dart';
import 'activity_detail.dart';

/// 仪表盘：本周跑量卡、ATL/CTL/TSB 负荷趋势、今日课表卡、最近活动。
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('仪表盘')),
      body: Consumer<StatsProvider>(
        builder: (BuildContext context, StatsProvider stats, _) {
          final Dashboard? dash = stats.dashboard;
          if (stats.loading && dash == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (stats.error != null && dash == null) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: '加载失败',
              message: stats.error,
              actionLabel: '重试',
              onAction: () => context.read<StatsProvider>().load(),
            );
          }
          if (dash == null) {
            return const EmptyState(title: '暂无数据');
          }
          return RefreshIndicator(
            onRefresh: () => context.read<StatsProvider>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _WeekSummaryCard(dashboard: dash),
                const SectionHeader(title: '负荷趋势（ATL / CTL / TSB）'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LoadTrendChart(points: dash.loadTrend),
                  ),
                ),
                const SectionHeader(title: '今日课表'),
                if (dash.todayWorkout != null)
                  WorkoutCard(workout: dash.todayWorkout!)
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('今日无课表安排，注意休息或轻松跑。'),
                    ),
                  ),
                const SectionHeader(title: '最近活动'),
                if (dash.recentActivities.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无活动。可在「我的 → 数据连接」同步 Mock 数据或导入 GPX。'),
                    ),
                  )
                else
                  ...dash.recentActivities.take(5).map(
                        (a) => ActivityTile(
                          activity: a,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ActivityDetailPage(activityId: a.id),
                              ),
                            );
                          },
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

class _WeekSummaryCard extends StatelessWidget {
  final Dashboard dashboard;

  const _WeekSummaryCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('本周跑量', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  dashboard.weekKm.toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text('km · ${dashboard.weekCount} 次',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _LoadChip(
                    label: 'ATL 疲劳',
                    value: dashboard.atl,
                    color: AppColors.secondary),
                const SizedBox(width: 8),
                _LoadChip(
                    label: 'CTL 体能',
                    value: dashboard.ctl,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _LoadChip(
                    label: 'TSB 状态',
                    value: dashboard.tsb,
                    color: const Color(0xFFFFD93D)),
              ],
            ),
            if (dashboard.planCompletion != null) ...<Widget>[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      dashboard.planCompletion!.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '计划完成度 ${(dashboard.planCompletion! * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _LoadChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              value.toStringAsFixed(0),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
