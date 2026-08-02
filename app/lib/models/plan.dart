import 'model_utils.dart';

/// 训练计划（training_plans，camelCase）
class TrainingPlan {
  final String id;
  final String name;
  final String raceType;
  final int? goalTimeSec;
  final String? raceDate;
  final String? startDate;
  final int? weeks;
  final int? sessionsPerWeek;
  final double? vdot;
  final String status;

  const TrainingPlan({
    required this.id,
    required this.name,
    this.raceType = 'full',
    this.goalTimeSec,
    this.raceDate,
    this.startDate,
    this.weeks,
    this.sessionsPerWeek,
    this.vdot,
    this.status = 'active',
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    return TrainingPlan(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? '训练计划',
      raceType: asString(json['raceType']) ?? 'full',
      goalTimeSec: asInt(json['goalTimeSec']),
      raceDate: asString(json['raceDate']),
      startDate: asString(json['startDate']),
      weeks: asInt(json['weeks']),
      sessionsPerWeek: asInt(json['sessionsPerWeek']),
      vdot: asDouble(json['vdot']),
      status: asString(json['status']) ?? 'active',
    );
  }
}

/// 课表（plan_workouts）
class PlanWorkout {
  final String id;
  final int? date; // epoch ms
  final int weekNo;
  final int? dayOfWeek;
  final String workoutType;
  final String title;
  final String? description;
  final double? targetDistanceM;
  final int? targetDurationSec;
  final int? paceMinSec;
  final int? paceMaxSec;
  final int? hrZone;
  final String status;
  final String? activityId;

  const PlanWorkout({
    required this.id,
    this.date,
    this.weekNo = 1,
    this.dayOfWeek,
    this.workoutType = 'E',
    this.title = '',
    this.description,
    this.targetDistanceM,
    this.targetDurationSec,
    this.paceMinSec,
    this.paceMaxSec,
    this.hrZone,
    this.status = 'pending',
    this.activityId,
  });

  factory PlanWorkout.fromJson(Map<String, dynamic> json) {
    return PlanWorkout(
      id: asString(json['id']) ?? '',
      date: asEpochMs(json['date']),
      weekNo: asInt(json['weekNo']) ?? 1,
      dayOfWeek: asInt(json['dayOfWeek']),
      workoutType: asString(json['workoutType']) ?? 'E',
      title: asString(json['title']) ?? '',
      description: asString(json['description']),
      targetDistanceM: asDouble(json['targetDistanceM']),
      targetDurationSec: asInt(json['targetDurationSec']),
      paceMinSec: asInt(json['paceMinSec']),
      paceMaxSec: asInt(json['paceMaxSec']),
      hrZone: asInt(json['hrZone']),
      status: asString(json['status']) ?? 'pending',
      activityId: asString(json['activityId']),
    );
  }

  PlanWorkout copyWith({String? status, String? activityId}) {
    return PlanWorkout(
      id: id,
      date: date,
      weekNo: weekNo,
      dayOfWeek: dayOfWeek,
      workoutType: workoutType,
      title: title,
      description: description,
      targetDistanceM: targetDistanceM,
      targetDurationSec: targetDurationSec,
      paceMinSec: paceMinSec,
      paceMaxSec: paceMaxSec,
      hrZone: hrZone,
      status: status ?? this.status,
      activityId: activityId ?? this.activityId,
    );
  }
}

/// 计划详情（计划 + 全部课表）
class PlanDetail {
  final TrainingPlan plan;
  final List<PlanWorkout> workouts;

  const PlanDetail({required this.plan, required this.workouts});

  /// 每周目标跑量（km），按 weekNo 聚合
  Map<int, double> weeklyKm() {
    final Map<int, double> result = <int, double>{};
    for (final PlanWorkout w in workouts) {
      result[w.weekNo] =
          (result[w.weekNo] ?? 0) + (w.targetDistanceM ?? 0) / 1000;
    }
    return result;
  }

  int get doneCount => workouts.where((w) => w.status == 'done').length;
}

/// 配速区间（秒/公里）
class PaceZoneRange {
  final int? minSec;
  final int? maxSec;

  const PaceZoneRange({this.minSec, this.maxSec});

  factory PaceZoneRange.fromJson(Map<String, dynamic> json) {
    return PaceZoneRange(
      minSec: asInt(json['minSec'] ?? json['min'] ?? json['fast']),
      maxSec: asInt(json['maxSec'] ?? json['max'] ?? json['slow']),
    );
  }
}

/// preview 周概览
class PlanPreviewWeek {
  final int weekNo;
  final String phase;
  final double targetKm;
  final int? sessions;

  const PlanPreviewWeek({
    required this.weekNo,
    this.phase = 'base',
    this.targetKm = 0,
    this.sessions,
  });

  factory PlanPreviewWeek.fromJson(Map<String, dynamic> json) {
    return PlanPreviewWeek(
      weekNo: asInt(json['weekNo'] ?? json['week']) ?? 0,
      phase: asString(json['phase']) ?? 'base',
      targetKm: asDouble(json['targetKm'] ?? json['km']) ?? 0,
      sessions: asInt(json['sessions']),
    );
  }
}

/// /plans/preview 返回
class PlanPreview {
  final double? vdot;
  final Map<String, PaceZoneRange> paceZones;
  final List<PlanPreviewWeek> weeks;
  final List<String> warnings;

  const PlanPreview({
    this.vdot,
    this.paceZones = const <String, PaceZoneRange>{},
    this.weeks = const <PlanPreviewWeek>[],
    this.warnings = const <String>[],
  });

  factory PlanPreview.fromJson(Map<String, dynamic> json) {
    final Map<String, PaceZoneRange> zones = <String, PaceZoneRange>{};
    final Map<String, dynamic> rawZones =
        asMap(json['paceZones'] ?? json['paces']);
    rawZones.forEach((String key, dynamic value) {
      if (value is Map) {
        zones[key] = PaceZoneRange.fromJson(Map<String, dynamic>.from(value));
      }
    });
    final List<String> warnings = <String>[];
    final dynamic rawWarnings = json['warnings'] ?? json['warning'];
    if (rawWarnings is List) {
      for (final dynamic w in rawWarnings) {
        warnings.add(w.toString());
      }
    } else if (rawWarnings != null) {
      warnings.add(rawWarnings.toString());
    }
    return PlanPreview(
      vdot: asDouble(json['vdot']),
      paceZones: zones,
      weeks: asMapList(json['weeks'] ?? json['weekOverview'])
          .map(PlanPreviewWeek.fromJson)
          .toList(),
      warnings: warnings,
    );
  }
}

/// preview / 创建计划的参数
class PlanParams {
  String raceType;
  int? goalTimeSec;
  int? weeks;
  String? raceDate;
  int sessionsPerWeek;
  double? vdot;
  String? startDate;
  String? name;

  PlanParams({
    this.raceType = 'full',
    this.goalTimeSec,
    this.weeks,
    this.raceDate,
    this.sessionsPerWeek = 4,
    this.vdot,
    this.startDate,
    this.name,
  });

  Map<String, dynamic> toJson({bool includeName = false}) {
    final Map<String, dynamic> map = <String, dynamic>{
      'raceType': raceType,
      'sessionsPerWeek': sessionsPerWeek,
    };
    if (goalTimeSec != null) map['goalTimeSec'] = goalTimeSec;
    if (weeks != null) map['weeks'] = weeks;
    if (raceDate != null) map['raceDate'] = raceDate;
    if (vdot != null) map['vdot'] = vdot;
    if (startDate != null) map['startDate'] = startDate;
    if (includeName && name != null && name!.isNotEmpty) map['name'] = name;
    return map;
  }
}
