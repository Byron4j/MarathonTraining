import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';

/// 心率区间行（Z1–Z5 色带）
class HrZoneRow extends StatelessWidget {
  final HrZone zone;

  const HrZoneRow({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.zoneColor(zone.zone);
    final String range = (zone.minHr != null && zone.maxHr != null)
        ? '${zone.minHr} – ${zone.maxHr} bpm'
        : '--';
    final String pct = (zone.pctMin != null && zone.pctMax != null)
        ? 'HRR ${(zone.pctMin! * 100).round()}–${(zone.pctMax! * 100).round()}%'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Z${zone.zone}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(zone.name,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (pct.isNotEmpty)
            Text(pct, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(range, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// 配速区间渐变条
class PaceRangeBar extends StatelessWidget {
  final Color color;

  const PaceRangeBar({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
          colors: <Color>[color.withOpacity(0.35), color],
        ),
      ),
    );
  }
}

/// 心率区间色带（5 段，高亮目标区间）
class HrZoneStrip extends StatelessWidget {
  final int? activeZone;

  const HrZoneStrip({super.key, this.activeZone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(5, (int i) {
        final int zone = i + 1;
        final bool active = zone == activeZone;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i < 4 ? 2 : 0),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.zoneColor(zone)
                  : AppColors.zoneColor(zone).withOpacity(0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
