/// Structured error codes shared with the backend contract (spec §61).
enum ErrorCode {
  networkError,
  authError,
  validationError,
  conflictError,
  permissionError,
  fileError,
  unknown;

  static ErrorCode fromWire(String? code) => switch (code) {
        'NETWORK_ERROR' => networkError,
        'AUTH_ERROR' => authError,
        'VALIDATION_ERROR' => validationError,
        'CONFLICT_ERROR' => conflictError,
        'PERMISSION_ERROR' => permissionError,
        'FILE_ERROR' => fileError,
        _ => unknown,
      };
}

/// What the UI sees. `technical` is for logs only and must never be displayed.
class AppError implements Exception {
  const AppError(this.code, {this.technical});
  final ErrorCode code;
  final String? technical;

  @override
  String toString() => 'AppError($code)';
}
