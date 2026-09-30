import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_state.dart';
import '../../features/more/more_page.dart';
import '../../features/shell/pending_page.dart';
import '../../features/shell/shell_page.dart';
import '../../features/splash/splash_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const classes = '/classes';
  static const planner = '/planner';
  static const analytics = '/analytics';
  static const more = '/more';
}

/// Pure redirect rule, unit-tested. While the session is unknown only the splash is shown;
/// afterwards the splash (and login, when signed in) forward to the right place.
String? resolveRedirect({required AuthStatus status, required String location}) {
  switch (status) {
    case AuthStatus.unknown:
      return location == Routes.splash ? null : Routes.splash;
    case AuthStatus.unauthenticated:
      return location == Routes.login ? null : Routes.login;
    case AuthStatus.authenticated:
      return (location == Routes.login || location == Routes.splash) ? Routes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier<AuthStatus>(ref.read(authStatusProvider));
  ref.listen<AuthStatus>(authStatusProvider, (_, next) => status.value = next);
  ref.onDispose(status.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: status,
    redirect: (_, state) => resolveRedirect(status: status.value, location: state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, __) => const PendingPage(phase: 1, titleKey: PendingTitle.signIn)),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPage(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const PendingPage(phase: 1, titleKey: PendingTitle.home)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.classes, builder: (_, __) => const PendingPage(phase: 1, titleKey: PendingTitle.classes)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.planner, builder: (_, __) => const PendingPage(phase: 2, titleKey: PendingTitle.planner)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.analytics, builder: (_, __) => const PendingPage(phase: 4, titleKey: PendingTitle.analytics)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.more, builder: (_, __) => const MorePage()),
          ]),
        ],
      ),
    ],
  );
});
