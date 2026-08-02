import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/model_utils.dart';
import '../models/profile.dart';

/// 档案接口（docs/03 第 2 节）
class ProfileRepository {
  final ApiClient _api;

  ProfileRepository(this._api);

  Future<Profile> getProfile() async {
    final Response<dynamic> res = await _api.dio.get('/profile');
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> profileJson =
        data['profile'] is Map ? asMap(data['profile']) : data;
    return Profile.fromJson(profileJson);
  }

  Future<Profile> updateProfile(Profile profile) async {
    final Response<dynamic> res =
        await _api.dio.put('/profile', data: profile.toJson());
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> profileJson =
        data['profile'] is Map ? asMap(data['profile']) : data;
    return Profile.fromJson(profileJson);
  }

  /// 心率区间 + 各区间定义
  Future<List<HrZone>> getZones() async {
    final Response<dynamic> res = await _api.dio.get('/profile/zones');
    final Map<String, dynamic> data = asMap(res.data);
    return asMapList(data['zones']).map(HrZone.fromJson).toList();
  }
}
