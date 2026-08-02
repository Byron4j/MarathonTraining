import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/stats.dart';

/// ATL/CTL/TSB 负荷趋势折线图（fl_chart 0.6x API）
class LoadTrendChart extends StatelessWidget {
  final List<LoadPoint> points;

  const LoadTrendChart({super.key, required this.points});

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('暂无负荷数据')),
      );
    }
    final int n = points.length;
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (final LoadPoint p in points) {
      for (final double v in <double>[p.atl, p.ctl, p.tsb]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    if (!minY.isFinite || !maxY.isFinite || maxY == minY) {
      minY = minY.isFinite ? minY - 5 : 0;
      maxY = maxY.isFinite ? maxY + 5 : 10;
    }
    final double bottomInterval = n <= 6 ? 1 : (n / 6).ceilToDouble();
    final double leftInterval = ((maxY - minY) / 4).clamp(1, 9999).toDouble();

    List<FlSpot> spotsOf(double Function(LoadPoint) pick) {
      return <FlSpot>[
        for (int i = 0; i < n; i++) FlSpot(i.toDouble(), pick(points[i])),
      ];
    }

    return Semantics(
      label: 'ATL/CTL/TSB 负荷趋势图，共 $n 个数据点',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              _LegendDot(color: AppColors.secondary, label: 'ATL 疲劳'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.primary, label: 'CTL 体能'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFFFFD93D), label: 'TSB 状态'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (n - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (double v) => FlLine(
                    color: Colors.white10,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: leftInterval,
                      getTitlesWidget: (double v, TitleMeta meta) => Text(
                        v.round().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: bottomInterval,
                      getTitlesWidget: (double v, TitleMeta meta) {
                        final int i = v.toInt();
                        if (v != i.toDouble() || i < 0 || i >= n) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formatMonthDay(points[i].date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  _line(spotsOf((p) => p.atl), AppColors.secondary),
                  _line(spotsOf((p) => p.ctl), AppColors.primary),
                  _line(spotsOf((p) => p.tsb), const Color(0xFFFFD93D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 单指标折线图（配速/心率曲线）
class MetricLineChart extends StatelessWidget {
  final List<num> values;
  final Color color;
  final int sampleSec;
  final String Function(num value) yLabel;

  const MetricLineChart({
    super.key,
    required this.values,
    required this.color,
    this.sampleSec = 5,
    required this.yLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('暂无数据')),
      );
    }
    final int n = values.length;
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (final num v in values) {
      if (v < minY) minY = v.toDouble();
      if (v > maxY) maxY = v.toDouble();
    }
    if (maxY == minY) {
      maxY += 1;
      minY -= 1;
    }
    final double pad = (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;
    final double bottomInterval = n <= 6 ? 1 : (n / 6).ceilToDouble();
    final double leftInterval = (maxY - minY) / 4;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (double v) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: leftInterval,
                getTitlesWidget: (double v, TitleMeta meta) => Text(
                  yLabel(v),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: bottomInterval,
                getTitlesWidget: (double v, TitleMeta meta) {
                  final int i = v.toInt();
                  if (v != i.toDouble() || i < 0 || i >= n) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatDuration(i * sampleSec),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < n; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 柱状图条目
class VolumeBarItem {
  final String label;
  final double value;
  final Color color;

  const VolumeBarItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// 跑量柱状图（周跑量/计划周视图）
class VolumeBarChart extends StatelessWidget {
  final List<VolumeBarItem> items;
  final double height;

  const VolumeBarChart({super.key, required this.items, this.height = 160});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无数据')),
      );
    }
    final int n = items.length;
    double maxY = 0;
    for (final VolumeBarItem item in items) {
      if (item.value > maxY) maxY = item.value;
    }
    if (maxY <= 0) maxY = 1;
    final double barWidth = n > 16 ? 6 : (n > 10 ? 10 : 16);
    final double bottomInterval = n <= 8 ? 1 : (n / 8).ceilToDouble();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY * 1.25,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: maxY,
                getTitlesWidget: (double v, TitleMeta meta) {
                  if (v != 0 && v != maxY) return const SizedBox.shrink();
                  return Text(
                    v.round().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: bottomInterval,
                getTitlesWidget: (double v, TitleMeta meta) {
                  final int i = v.toInt();
                  if (v != i.toDouble() || i < 0 || i >= n) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      items[i].label,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < n; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: items[i].value,
                    color: items[i].color,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
