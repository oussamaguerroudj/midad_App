import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_mapper.dart';
import '../../core/error/error_messages.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _schoolNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final l10n = AppLocalizations.of(context);

    try {
      final auth = ref.read(authStatusProvider.notifier);
      if (_isRegister) {
        await auth.register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          schoolName: _schoolNameController.text.isNotEmpty ? _schoolNameController.text : null,
        );
      } else {
        await auth.login(
          _emailController.text,
          _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = mapError(e);
        setState(() {
          _errorMessage = errorMessage(l10n, appError);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo mark & title
                  Image.asset(
                    'assets/brand/midad_mark.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.appName,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.tagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Auth Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isRegister ? l10n.signUp : l10n.signIn,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.control,
                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            if (_isRegister) ...[
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  labelText: l10n.fullName,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(borderRadius: AppRadius.control),
                                ),
                                validator: (v) => (v == null || v.trim().length < 2) ? l10n.errValidation : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _schoolNameController,
                                decoration: InputDecoration(
                                  labelText: l10n.schoolName,
                                  prefixIcon: const Icon(Icons.school_outlined),
                                  border: OutlineInputBorder(borderRadius: AppRadius.control),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: l10n.email,
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: AppRadius.control),
                              ),
                              validator: (v) => (v == null || !v.contains('@')) ? l10n.errValidation : null,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: l10n.password,
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(borderRadius: AppRadius.control),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? l10n.errValidation : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_isRegister ? l10n.registerAction : l10n.loginAction),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRegister = !_isRegister;
                                        _errorMessage = null;
                                      });
                                    },
                              child: Text(_isRegister ? l10n.haveAccount : l10n.noAccount),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
