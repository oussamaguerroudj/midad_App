import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Phase 0 stub. Phase 1 replaces this with real session restoration from secure storage.
/// Without the dev flag the app is (correctly) unauthenticated: no fake sessions exist.
class AuthStatusController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.unknown;

  Future<void> restoreSession() async {
    state = Env.devSkipAuth ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }
}

final authStatusProvider = NotifierProvider<AuthStatusController, AuthStatus>(AuthStatusController.new);
