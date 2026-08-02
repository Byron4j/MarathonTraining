import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/model_utils.dart';
import '../models/user.dart';

/// 认证接口（docs/03 第 1 节）
class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<AuthResult> login(String email, String password) async {
    final Response<dynamic> res = await _api.dio.post(
      '/auth/login',
      data: <String, dynamic>{'email': email, 'password': password},
    );
    return AuthResult.fromJson(asMap(res.data));
  }

  Future<AuthResult> register(
    String email,
    String password, {
    String? nickname,
  }) async {
    final Response<dynamic> res = await _api.dio.post(
      '/auth/register',
      data: <String, dynamic>{
        'email': email,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      },
    );
    return AuthResult.fromJson(asMap(res.data));
  }

  Future<User> me() async {
    final Response<dynamic> res = await _api.dio.get('/auth/me');
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> userJson =
        data['user'] is Map ? asMap(data['user']) : data;
    return User.fromJson(userJson);
  }

  Future<void> logout(String? refreshToken) async {
    await _api.dio.post(
      '/auth/logout',
      data: <String, dynamic>{
        if (refreshToken != null) 'refreshToken': refreshToken,
      },
    );
  }
}
