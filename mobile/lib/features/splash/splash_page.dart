import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_state.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authStatusProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppAnimations.slow,
          curve: AppAnimations.curve,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/brand/midad_mark.png', width: 160, height: 160, excludeFromSemantics: true),
              const SizedBox(height: AppSpacing.lg),
              Text(l.appName, style: t.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(l.tagline, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
