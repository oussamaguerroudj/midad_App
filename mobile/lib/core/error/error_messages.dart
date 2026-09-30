import '../l10n/generated/app_localizations.dart';
import 'app_error.dart';

/// Teacher-facing, localized, neutral text for each error code.
String errorMessage(AppLocalizations l, AppError e) => switch (e.code) {
      ErrorCode.networkError => l.errNetwork,
      ErrorCode.authError => l.errAuth,
      ErrorCode.validationError => l.errValidation,
      ErrorCode.conflictError => l.errConflict,
      ErrorCode.permissionError => l.errPermission,
      ErrorCode.fileError => l.errFile,
      ErrorCode.unknown => l.errUnknown,
    };
