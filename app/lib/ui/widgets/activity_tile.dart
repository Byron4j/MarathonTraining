import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/activity.dart';

/// 活动列表项（含 provider 标签）
class ActivityTile extends StatelessWidget {
  final Activity activity;
  final bool selected;
  final VoidCallback? onTap;

  const ActivityTile({
    super.key,
    required this.activity,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                child: Column(
                  children: <Widget>[
                    Text(
                      formatMonthDay(activity.startTime),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      activity.startTime != null
                          ? TimeOfDay.fromDateTime(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      activity.startTime!))
                              .format(context)
                          : '--',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${formatDistance(activity.distanceM)} · ${formatDuration(activity.durationSec)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '配速 ${formatPace(activity.avgPaceSecPerKm)}'
                      '${activity.avgHr != null ? ' · 心率 ${activity.avgHr}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  providerLabel(activity.provider),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
