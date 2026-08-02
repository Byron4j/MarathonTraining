import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/plan.dart';
import 'zone_widgets.dart';

/// 课表卡片：课型徽章 + 配速区间渐变条 + 心率区间色带 + 标记完成。
class WorkoutCard extends StatelessWidget {
  final PlanWorkout workout;
  final bool marking;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkSkipped;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.marking = false,
    this.onMarkDone,
    this.onMarkSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final Color typeColor = workoutTypeColor(workout.workoutType);
    final bool pending = workout.status == 'pending';
    final String? paceText =
        (workout.paceMinSec != null && workout.paceMaxSec != null)
            ? '${formatPace(workout.paceMinSec)} – ${formatPace(workout.paceMaxSec)} /km'
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    workout.workoutType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        workout.title.isNotEmpty
                            ? workout.title
                            : workoutTypeLabel(workout.workoutType),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${workoutTypeLabel(workout.workoutType)} · ${formatDate(workout.date)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: workout.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: <Widget>[
                if (workout.targetDistanceM != null)
                  Text('距离 ${formatDistance(workout.targetDistanceM)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                if (workout.targetDurationSec != null)
                  Text('时长 ${formatDuration(workout.targetDurationSec)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                if (workout.hrZone != null)
                  Text('心率 Z${workout.hrZone}',
                      style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (paceText != null) ...<Widget>[
              const SizedBox(height: 8),
              PaceRangeBar(color: typeColor),
              const SizedBox(height: 4),
              Text('配速 $paceText',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            HrZoneStrip(activeZone: workout.hrZone),
            if (workout.description != null &&
                workout.description!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(workout.description!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (pending && (onMarkDone != null || onMarkSkipped != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (marking)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...<Widget>[
                      if (onMarkSkipped != null)
                        TextButton(
                          onPressed: onMarkSkipped,
                          child: const Text('跳过'),
                        ),
                      if (onMarkDone != null)
                        FilledButton.tonalIcon(
                          onPressed: onMarkDone,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('标记完成'),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'done':
        color = AppColors.primary;
        break;
      case 'missed':
        color = AppColors.heartRed;
        break;
      case 'skipped':
        color = AppColors.secondary;
        break;
      default:
        color = AppColors.surfaceDarkHigh;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(status == 'pending' ? 1 : 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        workoutStatusLabel(status),
        style: TextStyle(
          fontSize: 12,
          color: status == 'pending'
              ? Theme.of(context).textTheme.bodySmall?.color
              : color,
        ),
      ),
    );
  }
}
