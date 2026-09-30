import 'package:flutter_test/flutter_test.dart';
import 'package:midad/core/router/app_router.dart';
import 'package:midad/features/auth/auth_state.dart';

void main() {
  test('unknown session stays on splash', () {
    expect(resolveRedirect(status: AuthStatus.unknown, location: Routes.splash), isNull);
    expect(resolveRedirect(status: AuthStatus.unknown, location: Routes.home), Routes.splash);
  });

  test('unauthenticated users are sent to login', () {
    expect(resolveRedirect(status: AuthStatus.unauthenticated, location: Routes.splash), Routes.login);
    expect(resolveRedirect(status: AuthStatus.unauthenticated, location: Routes.classes), Routes.login);
    expect(resolveRedirect(status: AuthStatus.unauthenticated, location: Routes.login), isNull);
  });

  test('authenticated users skip splash and login', () {
    expect(resolveRedirect(status: AuthStatus.authenticated, location: Routes.splash), Routes.home);
    expect(resolveRedirect(status: AuthStatus.authenticated, location: Routes.login), Routes.home);
    expect(resolveRedirect(status: AuthStatus.authenticated, location: Routes.classes), isNull);
  });
}
