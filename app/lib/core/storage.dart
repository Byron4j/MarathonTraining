import 'package:shared_preferences/shared_preferences.dart';

/// 本地 KV 存储（token 等）。
class Storage {
  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';

  final SharedPreferences _prefs;

  Storage._(this._prefs);

  static Future<Storage> create() async {
    return Storage._(await SharedPreferences.getInstance());
  }

  Future<String?> get accessToken async => _prefs.getString(_kAccessToken);

  Future<String?> get refreshToken async => _prefs.getString(_kRefreshToken);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_kAccessToken, accessToken);
    await _prefs.setString(_kRefreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
  }
}
