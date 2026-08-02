import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/model_utils.dart';
import '../models/stats.dart';

/// 统计接口（docs/03 第 6 节）
class StatsRepository {
  final ApiClient _api;

  StatsRepository(this._api);

  Future<Dashboard> dashboard() async {
    final Response<dynamic> res = await _api.dio.get('/stats/dashboard');
    return Dashboard.fromJson(asMap(res.data));
  }

  Future<List<WeeklyStat>> weekly({int weeks = 12}) async {
    final Response<dynamic> res = await _api.dio.get(
      '/stats/weekly',
      queryParameters: <String, dynamic>{'weeks': weeks},
    );
    final dynamic data = res.data;
    if (data is List) return asMapList(data).map(WeeklyStat.fromJson).toList();
    final Map<String, dynamic> map = asMap(data);
    return asMapList(map['weeks'] ?? map['items'])
        .map(WeeklyStat.fromJson)
        .toList();
  }
}
