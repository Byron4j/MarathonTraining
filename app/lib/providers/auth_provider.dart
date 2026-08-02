import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final Storage _storage;
  final ApiClient _api;

  AuthStatus status = AuthStatus.unknown;
  User? user;
  bool busy = false;
  String? error;

  AuthProvider(this._repo, this._storage, this._api) {
    _api.onSessionExpired = _handleSessionExpired;
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// 启动时恢复会话
  Future<void> bootstrap() async {
    final String? token = await _storage.accessToken;
    if (token == null || token.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _repo.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    return _runAuth(() => _repo.login(email, password));
  }

  Future<bool> register(String email, String password, String? nickname) async {
    return _runAuth(() => _repo.register(email, password, nickname: nickname));
  }

  Future<bool> _runAuth(Future<AuthResult> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final AuthResult result = await action();
      await _storage.saveTokens(
        accessToken: result.tokens.accessToken,
        refreshToken: result.tokens.refreshToken,
      );
      user = result.user;
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final String? refreshToken = await _storage.refreshToken;
    try {
      await _repo.logout(refreshToken);
    } catch (_) {
      // 吊销失败不阻塞本地登出
    }
    await _storage.clearTokens();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _handleSessionExpired() {
    if (status == AuthStatus.authenticated) {
      user = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }
}
