import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import 'auth_interceptor.dart';

/// Dio factory with authentication and logging.
Dio buildDio({
  FlutterSecureStorage? storage,
  void Function()? onSessionExpired,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ));

  if (storage != null) {
    dio.interceptors.add(AuthInterceptor(
      storage: storage,
      dio: dio,
      onSessionExpired: onSessionExpired,
    ));
  }

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }

  return dio;
}
