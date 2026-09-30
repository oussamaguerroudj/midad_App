import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

final currentTeacherProvider = StateProvider<TeacherInfo?>((ref) => null);

class AuthStatusController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.unknown;

  Future<void> restoreSession() async {
    if (Env.devSkipAuth) {
      state = AuthStatus.authenticated;
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final hasToken = await repo.hasValidToken();
      if (hasToken) {
        final teacher = await repo.getSavedTeacher();
        ref.read(currentTeacherProvider.notifier).state = teacher;
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    } catch (_) {
      state = AuthStatus.unauthenticated;
    }
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final teacher = await repo.login(email: email, password: password);
    ref.read(currentTeacherProvider.notifier).state = teacher;
    state = AuthStatus.authenticated;
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? schoolName,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final teacher = await repo.register(
      email: email,
      password: password,
      fullName: fullName,
      schoolName: schoolName,
    );
    ref.read(currentTeacherProvider.notifier).state = teacher;
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    ref.read(currentTeacherProvider.notifier).state = null;
    state = AuthStatus.unauthenticated;
  }
}

final authStatusProvider = NotifierProvider<AuthStatusController, AuthStatus>(AuthStatusController.new);
