import 'activity.dart';
import 'model_utils.dart';
import 'plan.dart';

/// ATL/CTL/TSB 趋势点
class LoadPoint {
  final int? date; // epoch ms
  final double atl;
  final double ctl;
  final double tsb;

  const LoadPoint({
    this.date,
    this.atl = 0,
    this.ctl = 0,
    this.tsb = 0,
  });

  factory LoadPoint.fromJson(Map<String, dynamic> json) {
    return LoadPoint(
      date: asEpochMs(json['date'] ?? json['day']),
      atl: asDouble(json['atl']) ?? 0,
      ctl: asDouble(json['ctl']) ?? 0,
      tsb: asDouble(json['tsb']) ?? 0,
    );
  }
}

/// /stats/dashboard
class Dashboard {
  final double weekKm;
  final int weekCount;
  final double? planCompletion; // 0–1
  final double atl;
  final double ctl;
  final double tsb;
  final List<LoadPoint> loadTrend;
  final List<Activity> recentActivities;
  final PlanWorkout? todayWorkout;

  const Dashboard({
    this.weekKm = 0,
    this.weekCount = 0,
    this.planCompletion,
    this.atl = 0,
    this.ctl = 0,
    this.tsb = 0,
    this.loadTrend = const <LoadPoint>[],
    this.recentActivities = const <Activity>[],
    this.todayWorkout,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> today = asMap(json['todayWorkout']);
    return Dashboard(
      weekKm: asDouble(json['weekKm'] ?? json['weekDistanceKm']) ?? 0,
      weekCount: asInt(json['weekCount'] ?? json['weekSessions']) ?? 0,
      planCompletion: asDouble(json['planCompletion']),
      atl: asDouble(json['atl']) ?? 0,
      ctl: asDouble(json['ctl']) ?? 0,
      tsb: asDouble(json['tsb']) ?? 0,
      loadTrend: asMapList(json['loadTrend'] ?? json['trend'])
          .map(LoadPoint.fromJson)
          .toList(),
      recentActivities:
          asMapList(json['recentActivities'] ?? json['recent'])
              .map(Activity.fromJson)
              .toList(),
      todayWorkout: today.isEmpty ? null : PlanWorkout.fromJson(today),
    );
  }
}

/// /stats/weekly 单项
class WeeklyStat {
  final int? weekStart; // epoch ms
  final double km;
  final int count;
  final int? avgPaceSecPerKm;

  const WeeklyStat({
    this.weekStart,
    this.km = 0,
    this.count = 0,
    this.avgPaceSecPerKm,
  });

  factory WeeklyStat.fromJson(Map<String, dynamic> json) {
    return WeeklyStat(
      weekStart: asEpochMs(json['weekStart'] ?? json['week']),
      km: asDouble(json['km'] ?? json['distanceKm']) ?? 0,
      count: asInt(json['count'] ?? json['sessions']) ?? 0,
      avgPaceSecPerKm: asInt(json['avgPaceSecPerKm'] ?? json['avgPace']),
    );
  }
}
