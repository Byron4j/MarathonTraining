import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/activity.dart';
import '../models/model_utils.dart';

/// 活动接口（docs/03 第 3 节）
class ActivityRepository {
  final ApiClient _api;

  ActivityRepository(this._api);

  Future<PagedActivities> list({
    int page = 1,
    int pageSize = 20,
    int? from,
    int? to,
  }) async {
    final Response<dynamic> res = await _api.dio.get(
      '/activities',
      queryParameters: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    );
    return PagedActivities.fromJson(asMap(res.data));
  }

  Future<Activity> detail(String id) async {
    final Response<dynamic> res = await _api.dio.get('/activities/$id');
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> activityJson =
        data['activity'] is Map ? asMap(data['activity']) : data;
    return Activity.fromJson(activityJson);
  }

  Future<Activity> create(Map<String, dynamic> body) async {
    final Response<dynamic> res = await _api.dio.post('/activities', data: body);
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> activityJson =
        data['activity'] is Map ? asMap(data['activity']) : data;
    return Activity.fromJson(activityJson);
  }

  Future<void> delete(String id) async {
    await _api.dio.delete('/activities/$id');
  }

  /// GPX 文件导入：{filename, contentBase64}
  Future<ActivityImportResult> importFile(
    String filename,
    String contentBase64,
  ) async {
    final Response<dynamic> res = await _api.dio.post(
      '/activities/import',
      data: <String, dynamic>{
        'filename': filename,
        'contentBase64': contentBase64,
      },
    );
    final Map<String, dynamic> data = asMap(res.data);
    return ActivityImportResult(
      fileName: filename,
      added: asInt(data['added']) ?? (data['activity'] != null ? 1 : 0),
      skipped: asInt(data['skipped']) ?? 0,
    );
  }
}
