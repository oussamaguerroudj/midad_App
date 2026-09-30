import 'package:dio/dio.dart';

import 'app_error.dart';

/// Converts any thrown object into an [AppError]. Raw exceptions (e.g. DioException) never reach the UI.
AppError mapError(Object error) {
  if (error is AppError) return error;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return AppError(ErrorCode.networkError, technical: error.message);
      default:
        break;
    }
    final data = error.response?.data;
    final wire = (data is Map && data['error'] is Map) ? (data['error'] as Map)['code'] as String? : null;
    final byBody = ErrorCode.fromWire(wire);
    if (byBody != ErrorCode.unknown) return AppError(byBody, technical: error.message);
    return switch (error.response?.statusCode) {
      401 => AppError(ErrorCode.authError, technical: error.message),
      403 || 404 => AppError(ErrorCode.permissionError, technical: error.message),
      409 => AppError(ErrorCode.conflictError, technical: error.message),
      422 => AppError(ErrorCode.validationError, technical: error.message),
      _ => AppError(ErrorCode.unknown, technical: error.message),
    };
  }
  return AppError(ErrorCode.unknown, technical: error.toString());
}
