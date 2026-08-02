import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/model_utils.dart';
import '../models/sync.dart';

/// 同步接口（docs/03 第 4 节）
class SyncRepository {
  final ApiClient _api;

  SyncRepository(this._api);

  Future<List<SyncProviderInfo>> providers() async {
    final Response<dynamic> res = await _api.dio.get('/sync/providers');
    final dynamic data = res.data;
    if (data is List) {
      return asMapList(data).map(SyncProviderInfo.fromJson).toList();
    }
    final Map<String, dynamic> map = asMap(data);
    return asMapList(map['providers'] ?? map['items'])
        .map(SyncProviderInfo.fromJson)
        .toList();
  }

  Future<List<SyncConnection>> connections() async {
    final Response<dynamic> res = await _api.dio.get('/sync/connections');
    final dynamic data = res.data;
    if (data is List) {
      return asMapList(data).map(SyncConnection.fromJson).toList();
    }
    final Map<String, dynamic> map = asMap(data);
    return asMapList(map['connections'] ?? map['items'])
        .map(SyncConnection.fromJson)
        .toList();
  }

  /// 建立连接；coros 可能返回授权 URL
  Future<Map<String, dynamic>> connect(String provider) async {
    final Response<dynamic> res = await _api.dio.post(
      '/sync/connections',
      data: <String, dynamic>{'provider': provider},
    );
    return asMap(res.data);
  }

  /// 高驰 OAuth 授权链接
  Future<String> corosAuthorizeUrl() async {
    final Response<dynamic> res =
        await _api.dio.get('/sync/connections/coros/authorize-url');
    final Map<String, dynamic> data = asMap(res.data);
    final String? url =
        asString(data['url']) ?? asString(data['authorizeUrl']);
    if (url == null || url.isEmpty) {
      throw StateError('后端未返回授权链接');
    }
    return url;
  }

  Future<void> disconnect(String connectionId) async {
    await _api.dio.delete('/sync/connections/$connectionId');
  }

  /// 触发同步 → {jobId, added, skipped}
  Future<Map<String, dynamic>> syncConnection(String connectionId) async {
    final Response<dynamic> res =
        await _api.dio.post('/sync/connections/$connectionId/sync');
    return asMap(res.data);
  }

  Future<List<SyncJob>> jobs({int limit = 20}) async {
    final Response<dynamic> res = await _api.dio.get(
      '/sync/jobs',
      queryParameters: <String, dynamic>{'limit': limit},
    );
    final dynamic data = res.data;
    if (data is List) return asMapList(data).map(SyncJob.fromJson).toList();
    final Map<String, dynamic> map = asMap(data);
    return asMapList(map['jobs'] ?? map['items'])
        .map(SyncJob.fromJson)
        .toList();
  }
}
