/// 防御性 JSON 解析工具（服务端字段缺失/类型不一致时不抛异常）。
library;

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? asString(dynamic v) => v?.toString();

/// epoch 毫秒 / epoch 秒 / ISO 字符串 → epoch 毫秒
int? asEpochMs(dynamic v) {
  if (v == null) return null;
  if (v is int) return v > 100000000000 ? v : v * 1000;
  if (v is num) {
    final int n = v.toInt();
    return n > 100000000000 ? n : n * 1000;
  }
  if (v is String) {
    final int? n = int.tryParse(v);
    if (n != null) return n > 100000000000 ? n : n * 1000;
    final DateTime? dt = DateTime.tryParse(v);
    return dt?.millisecondsSinceEpoch;
  }
  return null;
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

List<num> asNumList(dynamic v) {
  if (v is List) return v.whereType<num>().toList();
  return const <num>[];
}
