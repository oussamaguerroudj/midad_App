import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/attendance_page.dart';
import '../../features/auth/auth_state.dart';
import '../../features/auth/login_page.dart';
import '../../features/classes/class_detail_page.dart';
import '../../features/classes/classes_page.dart';
import '../../features/gradebook/assessment_results_page.dart';
import '../../features/gradebook/gradebook_page.dart';
import '../../features/home/home_page.dart';
import '../../features/more/more_page.dart';
import '../../features/shell/pending_page.dart';
import '../../features/shell/shell_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/students/student_profile_page.dart';

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
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/classes/:id',
        builder: (_, state) => ClassDetailPage(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/classes/:id/attendance',
        builder: (_, state) => AttendancePage(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/classes/:id/gradebook',
        builder: (_, state) => GradebookPage(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/classes/:id/assessments/:assessmentId',
        builder: (_, state) => AssessmentResultsPage(
          classId: state.pathParameters['id']!,
          assessmentId: state.pathParameters['assessmentId']!,
        ),
      ),
      GoRoute(
        path: '/students/:id',
        builder: (_, state) => StudentProfilePage(studentId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPage(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.classes, builder: (_, __) => const ClassesPage()),
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
