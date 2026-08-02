import 'package:dio/dio.dart';

import 'storage.dart';

/// dio 封装：base URL 配置、Authorization 拦截、401 自动刷新重试。
class ApiClient {
  /// 通过 `--dart-define=API_BASE=http://x.x.x.x:8080/api/v1` 覆盖
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  final Storage storage;
  late final Dio dio;

  /// 会话彻底失效（刷新失败）时回调，由 AuthProvider 注册
  void Function()? onSessionExpired;

  Future<bool>? _refreshFuture;

  ApiClient(this.storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json; charset=utf-8',
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final String? token = await storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final int? status = error.response?.statusCode;
          final bool retried = error.requestOptions.extra['retried'] == true;
          final bool isAuthPath =
              error.requestOptions.path.startsWith('/auth/login') ||
                  error.requestOptions.path.startsWith('/auth/register') ||
                  error.requestOptions.path.startsWith('/auth/refresh');
          if (status == 401 && !retried && !isAuthPath) {
            final bool ok = await _refreshTokens();
            if (ok) {
              try {
                final RequestOptions opts = error.requestOptions;
                opts.extra['retried'] = true;
                final String? token = await storage.accessToken;
                if (token != null) {
                  opts.headers['Authorization'] = 'Bearer $token';
                }
                final Response<dynamic> response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
            onSessionExpired?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  /// 刷新令牌（并发请求共享同一次刷新）
  Future<bool> _refreshTokens() {
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<bool> _doRefresh() async {
    final String? refreshToken = await storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      // 用独立 Dio，避免触发自身拦截器
      final Dio raw = Dio(BaseOptions(baseUrl: baseUrl));
      final Response<dynamic> res = await raw.post(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final dynamic data = res.data;
      if (data is Map && data['tokens'] is Map) {
        final Map tokens = data['tokens'] as Map;
        final String? access = tokens['accessToken']?.toString();
        final String? refresh =
            tokens['refreshToken']?.toString() ?? refreshToken;
        if (access != null) {
          await storage.saveTokens(accessToken: access, refreshToken: refresh);
          return true;
        }
      }
      return false;
    } catch (_) {
      await storage.clearTokens();
      return false;
    }
  }
}

/// 从异常中提取服务端错误消息（错误约定见 docs/03）
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final dynamic msg = (data['error'] as Map)['message'];
      if (msg != null) return msg.toString();
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return '无法连接服务器，请确认后端已启动（${ApiClient.baseUrl}）';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '请求超时，请稍后重试';
      default:
        break;
    }
    final int? code = error.response?.statusCode;
    return code != null ? '请求失败（HTTP $code）' : '网络请求失败';
  }
  return error.toString();
}
