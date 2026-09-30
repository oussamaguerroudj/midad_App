import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/core/error/app_error.dart';
import 'package:midad/core/error/error_mapper.dart';

DioException _dio(DioExceptionType type, {int? status, Object? body}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    response: status == null ? null : Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  test('connection problems map to networkError', () {
    expect(mapError(_dio(DioExceptionType.connectionError)).code, ErrorCode.networkError);
    expect(mapError(_dio(DioExceptionType.receiveTimeout)).code, ErrorCode.networkError);
  });

  test('server error body code wins over status code', () {
    final e = mapError(_dio(DioExceptionType.badResponse, status: 409, body: {'error': {'code': 'CONFLICT_ERROR'}}));
    expect(e.code, ErrorCode.conflictError);
  });

  test('status fallback', () {
    expect(mapError(_dio(DioExceptionType.badResponse, status: 401)).code, ErrorCode.authError);
    expect(mapError(_dio(DioExceptionType.badResponse, status: 500)).code, ErrorCode.unknown);
  });

  test('unknown objects never leak: mapped to unknown', () {
    expect(mapError(StateError('boom')).code, ErrorCode.unknown);
  });
}
