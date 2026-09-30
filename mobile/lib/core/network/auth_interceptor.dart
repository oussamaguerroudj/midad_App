import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.dio,
    this.onSessionExpired,
  });

  final FlutterSecureStorage storage;
  final Dio dio;
  final void Function()? onSessionExpired;

  static const _kAccessTokenKey = 'midad_access_token';
  static const _kRefreshTokenKey = 'midad_refresh_token';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.read(key: _kAccessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      if (path.contains('/auth/login') || path.contains('/auth/register') || path.contains('/auth/refresh')) {
        return handler.next(err);
      }

      final refreshToken = await storage.read(key: _kRefreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        onSessionExpired?.call();
        return handler.next(err);
      }

      try {
        final refreshDio = Dio(BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

        final response = await refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200 && response.data != null) {
          final newAccess = response.data!['access_token'] as String;
          final newRefresh = response.data!['refresh_token'] as String;

          await storage.write(key: _kAccessTokenKey, value: newAccess);
          await storage.write(key: _kRefreshTokenKey, value: newRefresh);

          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccess';

          final clonedRequest = await dio.fetch<dynamic>(retryOptions);
          return handler.resolve(clonedRequest);
        }
      } catch (_) {
        await storage.delete(key: _kAccessTokenKey);
        await storage.delete(key: _kRefreshTokenKey);
        onSessionExpired?.call();
      }
    }
    handler.next(err);
  }
}
