import 'model_utils.dart';

/// 心率区间（储备心率法，见 docs/04 第 3 节）。
class HrZone {
  final int zone;
  final String name;
  final int? minHr;
  final int? maxHr;
  final double? pctMin;
  final double? pctMax;

  const HrZone({
    required this.zone,
    required this.name,
    this.minHr,
    this.maxHr,
    this.pctMin,
    this.pctMax,
  });

  factory HrZone.fromJson(Map<String, dynamic> json) {
    return HrZone(
      zone: asInt(json['zone']) ?? 0,
      name: asString(json['name']) ?? 'Z${asInt(json['zone']) ?? ''}',
      minHr: asInt(json['minHr']),
      maxHr: asInt(json['maxHr']),
      pctMin: asDouble(json['pctMin']),
      pctMax: asDouble(json['pctMax']),
    );
  }
}

/// 个人档案（字段与 docs/02 profiles 表 camelCase 对齐）。
class Profile {
  String? nickname;
  String? gender;
  String? birthDate;
  double? heightCm;
  double? weightKg;
  int? restingHr;
  int? maxHr;
  int? pb5kSec;
  int? pb10kSec;
  int? pbHalfSec;
  int? pbFullSec;
  double? weeklyKm;
  double? yearsRunning;
  List<HrZone> hrZones;

  Profile({
    this.nickname,
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.restingHr,
    this.maxHr,
    this.pb5kSec,
    this.pb10kSec,
    this.pbHalfSec,
    this.pbFullSec,
    this.weeklyKm,
    this.yearsRunning,
    List<HrZone>? hrZones,
  }) : hrZones = hrZones ?? <HrZone>[];

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      nickname: asString(json['nickname']),
      gender: asString(json['gender']),
      birthDate: asString(json['birthDate']),
      heightCm: asDouble(json['heightCm']),
      weightKg: asDouble(json['weightKg']),
      restingHr: asInt(json['restingHr']),
      maxHr: asInt(json['maxHr']),
      pb5kSec: asInt(json['pb5kSec']),
      pb10kSec: asInt(json['pb10kSec']),
      pbHalfSec: asInt(json['pbHalfSec']),
      pbFullSec: asInt(json['pbFullSec']),
      weeklyKm: asDouble(json['weeklyKm']),
      yearsRunning: asDouble(json['yearsRunning']),
      hrZones: asMapList(json['hrZones'] ?? json['zones'])
          .map(HrZone.fromJson)
          .toList(),
    );
  }

  /// PUT /profile 全量更新请求体
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nickname': nickname,
      'gender': gender,
      'birthDate': birthDate,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'restingHr': restingHr,
      'maxHr': maxHr,
      'pb5kSec': pb5kSec,
      'pb10kSec': pb10kSec,
      'pbHalfSec': pbHalfSec,
      'pbFullSec': pbFullSec,
      'weeklyKm': weeklyKm,
      'yearsRunning': yearsRunning,
    };
  }
}
