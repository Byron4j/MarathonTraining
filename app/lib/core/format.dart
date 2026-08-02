import 'package:intl/intl.dart';

/// 配速（秒/公里）→ "5'30\""
String formatPace(num? secPerKm) {
  if (secPerKm == null || secPerKm <= 0) return '--';
  final int total = secPerKm.round();
  final int m = total ~/ 60;
  final int s = total % 60;
  return "$m'${s.toString().padLeft(2, '0')}\"";
}

/// 时长（秒）→ "1:23:45"（不足 1 小时为 "23:45"）
String formatDuration(num? seconds) {
  if (seconds == null || seconds < 0) return '--';
  final int total = seconds.round();
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  final int s = total % 60;
  final String mm = m.toString().padLeft(2, '0');
  final String ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// 时长（秒）→ 固定 "h:mm:ss"（用于编辑表单回填）
String formatDurationHms(num? seconds) {
  if (seconds == null || seconds < 0) return '';
  final int total = seconds.round();
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  final int s = total % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 解析 "h:mm:ss" 或 "mm:ss" 或纯分钟数字 → 秒；失败返回 null
int? parseDurationText(String text) {
  final String t = text.trim();
  if (t.isEmpty) return null;
  final List<String> parts = t.split(':');
  int? h = 0, m = 0, s = 0;
  if (parts.length == 3) {
    h = int.tryParse(parts[0]);
    m = int.tryParse(parts[1]);
    s = int.tryParse(parts[2]);
  } else if (parts.length == 2) {
    m = int.tryParse(parts[0]);
    s = int.tryParse(parts[1]);
  } else if (parts.length == 1) {
    // 单个数字按秒解析不直观，按 "mm" 太歧义，拒绝
    return int.tryParse(t);
  } else {
    return null;
  }
  if (h == null || m == null || s == null) return null;
  if (m < 0 || m > 59 || s < 0 || s > 59 || h < 0) return null;
  return h * 3600 + m * 60 + s;
}

/// 距离（米）→ "10.0 km"（不足 1km 显示米）
String formatDistance(num? meters) {
  if (meters == null) return '--';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

/// 距离（米）→ 公里数（1 位小数）
String formatKm(num? meters) {
  if (meters == null) return '--';
  return (meters / 1000).toStringAsFixed(1);
}

final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
final DateFormat _monthDayFmt = DateFormat('MM-dd');
final DateFormat _dateTimeFmt = DateFormat('MM-dd HH:mm');

/// epoch 毫秒 → "2026-08-10"
String formatDate(int? epochMs) {
  if (epochMs == null) return '--';
  return _dateFmt.format(DateTime.fromMillisecondsSinceEpoch(epochMs));
}

/// epoch 毫秒 → "08-10"
String formatMonthDay(int? epochMs) {
  if (epochMs == null) return '--';
  return _monthDayFmt.format(DateTime.fromMillisecondsSinceEpoch(epochMs));
}

/// epoch 毫秒 → "08-10 06:30"
String formatDateTime(int? epochMs) {
  if (epochMs == null) return '--';
  return _dateTimeFmt.format(DateTime.fromMillisecondsSinceEpoch(epochMs));
}

/// DateTime → "2026-08-10"（API date 字段）
String toApiDate(DateTime dt) => _dateFmt.format(dt);

/// 比赛距离类型 → 中文
String raceTypeLabel(String? raceType) {
  switch (raceType) {
    case '5k':
      return '5 公里';
    case '10k':
      return '10 公里';
    case 'half':
      return '半程马拉松';
    case 'full':
      return '全程马拉松';
    default:
      return raceType ?? '--';
  }
}

/// 课型 → 中文
String workoutTypeLabel(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'E':
      return '轻松跑';
    case 'M':
      return '马拉松配速跑';
    case 'T':
      return '乳酸门槛跑';
    case 'I':
      return '间歇跑';
    case 'R':
      return '重复跑';
    case 'L':
      return '长距离';
    case 'RECOVERY':
      return '恢复跑';
    case 'XT':
      return '力量/交叉';
    case 'REST':
      return '休息';
    case 'RACE':
      return '比赛日';
    default:
      return type ?? '--';
  }
}

/// 数据来源 → 中文
String providerLabel(String? provider) {
  switch (provider) {
    case 'manual':
      return '手动';
    case 'mock':
      return '模拟';
    case 'coros':
      return '高驰';
    case 'file-gpx':
    case 'file':
      return '文件导入';
    case 'garmin':
      return '佳明';
    case 'huawei':
      return '华为';
    default:
      return provider ?? '--';
  }
}

/// 阶段 → 中文
String phaseLabel(String? phase) {
  switch ((phase ?? '').toLowerCase()) {
    case 'base':
      return '基础期';
    case 'build':
      return '进展期';
    case 'peak':
      return '巅峰期';
    case 'taper':
      return '减量期';
    default:
      return phase ?? '--';
  }
}

/// 课表状态 → 中文
String workoutStatusLabel(String? status) {
  switch (status) {
    case 'done':
      return '已完成';
    case 'missed':
      return '已错过';
    case 'skipped':
      return '已跳过';
    case 'pending':
    default:
      return '待完成';
  }
}
