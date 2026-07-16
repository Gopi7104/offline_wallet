import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/app/home_screen.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'package:offline_wallet/features/security/pin_setup_screen.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'auth_provider.dart';
import 'auth_service.dart';

/// Sign-in screen (Task 6.5): Email/Password (real `firebase_auth`), Google +
/// Apple (clearly "coming soon" — no project configured for this build), and
/// Guest Mode (always works, marked "Developer Preview").
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _afterAttempt() async {
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final err = state.error;
      if (err is AuthNotConfiguredException) {
        await showAppInfoDialog(context, title: 'Coming soon', message: '$err');
      } else {
        setState(() => _error = '$err');
      }
      return;
    }
    final pinSet = await ref.read(pinSetProvider.future);
    if (!mounted) return;
    if (pinSet) {
      Navigator.of(context).pushAndRemoveUntil(sharedAxisRoute(const HomeScreen()), (route) => false);
    } else {
      Navigator.of(context).pushReplacement(sharedAxisRoute(const PinSetupScreen()));
    }
  }

  Future<void> _submitEmail() async {
    setState(() => _error = null);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter an email and password.');
      return;
    }
    if (_isRegister) {
      if (name.isEmpty) {
        setState(() => _error = 'Enter your name.');
        return;
      }
      await ref.read(authControllerProvider.notifier).register(email, password, displayName: name);
    } else {
      await ref.read(authControllerProvider.notifier).signInWithEmail(email, password);
    }
    await _afterAttempt();
  }

  Future<void> _continueAsGuest() async {
    setState(() => _error = null);
    await ref.read(authControllerProvider.notifier).continueAsGuest();
    await _afterAttempt();
  }

  Future<void> _handleGoogle() async {
    setState(() => _error = null);
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    await _afterAttempt();
  }

  Future<void> _handleApple() async {
    setState(() => _error = null);
    await ref.read(authControllerProvider.notifier).signInWithApple();
    await _afterAttempt();
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password?".');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
      if (!mounted) return;
      await showAppInfoDialog(
        context,
        title: 'Check your email',
        message: 'If an account exists for $email, a password reset link is on its way.',
      );
    } catch (e) {
      if (!mounted) return;
      if (e is AuthNotConfiguredException) {
        await showAppInfoDialog(context, title: 'Coming soon', message: '$e');
      } else {
        setState(() => _error = '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: AppColors.primaryButtonGradient)
                    .createShader(bounds),
                child: const Icon(Symbols.bolt_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                _isRegister ? 'Create your account' : 'Welcome back',
                style: AppTypography.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to send and receive digital cash — online or off.',
                style: AppTypography.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_isRegister) ...[
                TextField(
                  key: const Key('auth-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Symbols.person_rounded)),
                ),
                const SizedBox(height: AppSpacing.base),
              ],
              TextField(
                key: const Key('auth-email-field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail_rounded)),
              ),
              const SizedBox(height: AppSpacing.base),
              TextField(
                key: const Key('auth-password-field'),
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Symbols.lock_rounded)),
              ),
              if (!_isRegister) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('auth-forgot-password-button'),
                    onPressed: loading ? null : _handleForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.base),
                Text(
                  _error!,
                  key: const Key('auth-error'),
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('auth-submit-button'),
                label: _isRegister ? 'Create account' : 'Sign In',
                loading: loading,
                onPressed: loading ? null : _submitEmail,
              ),
              const SizedBox(height: AppSpacing.base),
              TextButton(
                onPressed: loading ? null : () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? 'Already have an account? Sign in' : "New here? Create an account"),
              ),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    child: Text('or continue with', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              SecondaryButton(label: 'Google', icon: Symbols.g_mobiledata_rounded, onPressed: loading ? null : _handleGoogle),
              const SizedBox(height: AppSpacing.base),
              SecondaryButton(label: 'Apple', icon: Icons.apple, onPressed: loading ? null : _handleApple),
              const SizedBox(height: AppSpacing.xxl),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Symbols.visibility_rounded, size: 18, color: AppColors.accent),
                        SizedBox(width: AppSpacing.s),
                        Text('Developer Preview', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'Explore the full demo without an account. Guest data stays on this device.',
                      style: AppTypography.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.base),
                    SecondaryButton(
                      label: 'Continue as Guest',
                      icon: Symbols.arrow_forward_rounded,
                      onPressed: loading ? null : _continueAsGuest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
