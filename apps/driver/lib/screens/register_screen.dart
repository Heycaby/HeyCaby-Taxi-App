import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../router.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_entry_navigation.dart';
import '../widgets/driver_onboarding_gate_body.dart';

/// **Onboarding Gate** — join as a driver with confidence.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    HapticService.mediumTap();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await HeyCabySupabase.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: const {'user_type': 'driver'},
      );
      if (!mounted) return;
      await navigateDriverAfterAuth(
        ref: ref,
        router: appRouter,
        context: context,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('AuthException: ', '');
        _loading = false;
      });
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final compact = MediaQuery.sizeOf(context).height < 720;

    return DriverOnboardingGateBody(
      colors: colors,
      typography: typography,
      compact: compact,
      emailController: _emailController,
      passwordController: _passwordController,
      loading: _loading,
      error: _error,
      onBack: () => context.go('/login'),
      onSubmit: _signUp,
    );
  }
}
