import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/plan.dart';
import '../../providers/plan_provider.dart';
import '../widgets/common_widgets.dart';
import 'plan_detail_page.dart';
import 'plan_wizard_page.dart';

/// 训练计划页：进行中计划卡 + 计划列表 + 生成入口。
class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  Future<void> _openWizard(BuildContext context) async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PlanWizardPage()),
    );
    if (!context.mounted) return;
    if (created == true) {
      await context.read<PlanProvider>().loadPlans();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('训练计划已生成')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('训练计划')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成计划'),
      ),
      body: Consumer<PlanProvider>(
        builder: (BuildContext context, PlanProvider provider, _) {
          if (provider.loading && provider.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.plans.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: '加载失败',
              message: provider.error,
              actionLabel: '重试',
              onAction: () => context.read<PlanProvider>().loadPlans(),
            );
          }
          if (provider.plans.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_month_outlined,
              title: '还没有训练计划',
              message: '选择目标（5K / 10K / 半马 / 全马），3 步生成周期化课表。',
              actionLabel: '生成计划',
              onAction: () => _openWizard(context),
            );
          }
          final TrainingPlan? active = provider.activePlan;
          return RefreshIndicator(
            onRefresh: () => context.read<PlanProvider>().loadPlans(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (active != null) ...<Widget>[
                  const SectionHeader(title: '进行中'),
                  _PlanCard(plan: active, highlighted: true),
                ],
                const SectionHeader(title: '全部计划'),
                ...provider.plans.map(
                  (TrainingPlan p) => _PlanCard(
                    plan: p,
                    highlighted: p.id == active?.id,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TrainingPlan plan;
  final bool highlighted;

  const _PlanCard({required this.plan, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> meta = <String>[
      if (plan.startDate != null) '开始 ${plan.startDate}',
      if (plan.raceDate != null) '比赛 ${plan.raceDate}',
      if (plan.weeks != null) '${plan.weeks} 周',
      '每周 ${plan.sessionsPerWeek ?? '-'} 练',
    ];
    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlanDetailPage(planId: plan.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      plan.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      raceTypeLabel(plan.raceType),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(meta.join(' · '), style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: <Widget>[
                  if (plan.vdot != null)
                    Text('VDOT ${plan.vdot!.toStringAsFixed(1)}',
                        style: theme.textTheme.bodySmall),
                  if (plan.goalTimeSec != null)
                    Text('目标 ${formatDuration(plan.goalTimeSec)}',
                        style: theme.textTheme.bodySmall),
                  Text('状态 ${plan.status}', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
