import 'model_utils.dart';

/// 圈数据（activity_laps）
class ActivityLap {
  final int lapNo;
  final double? distanceM;
  final int? durationSec;
  final int? avgHr;
  final int? avgPaceSecPerKm;

  const ActivityLap({
    required this.lapNo,
    this.distanceM,
    this.durationSec,
    this.avgHr,
    this.avgPaceSecPerKm,
  });

  factory ActivityLap.fromJson(Map<String, dynamic> json) {
    return ActivityLap(
      lapNo: asInt(json['lapNo']) ?? 0,
      distanceM: asDouble(json['distanceM']),
      durationSec: asInt(json['durationSec']),
      avgHr: asInt(json['avgHr']),
      avgPaceSecPerKm: asInt(json['avgPace'] ?? json['avgPaceSecPerKm']),
    );
  }
}

/// 时间序列（activity_streams）
class ActivityStreams {
  final int sampleSec;
  final List<num> hr;
  final List<num> pace;
  final List<num> cadence;
  final List<num> alt;

  const ActivityStreams({
    this.sampleSec = 5,
    this.hr = const <num>[],
    this.pace = const <num>[],
    this.cadence = const <num>[],
    this.alt = const <num>[],
  });

  bool get hasData => hr.isNotEmpty || pace.isNotEmpty;

  factory ActivityStreams.fromJson(Map<String, dynamic> json) {
    return ActivityStreams(
      sampleSec: asInt(json['sampleSec']) ?? 5,
      hr: asNumList(json['hr']),
      pace: asNumList(json['pace']),
      cadence: asNumList(json['cadence']),
      alt: asNumList(json['alt']),
    );
  }
}

/// 统一活动模型（见 docs/02「统一活动模型 API JSON 形态」）
class Activity {
  final String id;
  final String provider;
  final String sport;
  final int? startTime; // epoch ms
  final int? durationSec;
  final double? distanceM;
  final double? elevationGainM;
  final int? avgPaceSecPerKm;
  final int? avgHr;
  final int? maxHr;
  final int? avgCadence;
  final int? calories;
  final double? trainingEffect;
  final String? sourceFile;
  final List<ActivityLap> laps;
  final ActivityStreams? streams;

  const Activity({
    required this.id,
    this.provider = 'manual',
    this.sport = 'run',
    this.startTime,
    this.durationSec,
    this.distanceM,
    this.elevationGainM,
    this.avgPaceSecPerKm,
    this.avgHr,
    this.maxHr,
    this.avgCadence,
    this.calories,
    this.trainingEffect,
    this.sourceFile,
    this.laps = const <ActivityLap>[],
    this.streams,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> streamsMap = asMap(json['streams']);
    return Activity(
      id: asString(json['id']) ?? '',
      provider: asString(json['provider']) ?? 'manual',
      sport: asString(json['sport']) ?? 'run',
      startTime: asEpochMs(json['startTime']),
      durationSec: asInt(json['durationSec']),
      distanceM: asDouble(json['distanceM']),
      elevationGainM: asDouble(json['elevationGainM']),
      avgPaceSecPerKm: asInt(json['avgPaceSecPerKm']),
      avgHr: asInt(json['avgHr']),
      maxHr: asInt(json['maxHr']),
      avgCadence: asInt(json['avgCadence']),
      calories: asInt(json['calories']),
      trainingEffect: asDouble(json['trainingEffect']),
      sourceFile: asString(json['sourceFile']),
      laps: asMapList(json['laps']).map(ActivityLap.fromJson).toList(),
      streams: streamsMap.isEmpty ? null : ActivityStreams.fromJson(streamsMap),
    );
  }
}

/// 分页结果（分页约定见 docs/03）
class PagedActivities {
  final List<Activity> items;
  final int page;
  final int pageSize;
  final int total;

  const PagedActivities({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PagedActivities.fromJson(Map<String, dynamic> json) {
    return PagedActivities(
      items: asMapList(json['items']).map(Activity.fromJson).toList(),
      page: asInt(json['page']) ?? 1,
      pageSize: asInt(json['pageSize']) ?? 20,
      total: asInt(json['total']) ?? 0,
    );
  }
}

/// GPX 导入结果
class ActivityImportResult {
  final String fileName;
  final int added;
  final int skipped;

  const ActivityImportResult({
    required this.fileName,
    required this.added,
    required this.skipped,
  });
}
