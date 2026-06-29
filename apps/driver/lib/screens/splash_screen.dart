import 'dart:async' show unawaited;
import 'dart:math' show sin, pi;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../router.dart';
import '../providers/driver_locale_provider.dart';
import '../providers/driver_runtime_providers.dart';
import '../utils/driver_entry_navigation.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_brand_moment_body.dart';

/// Total intro length — enough for staggered copy without feeling slow.
const _kTotalMs = 5200;

/// Driver welcome — logo on light background, value props below.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _pill1;
  late final Animation<double> _pill2;
  late final Animation<double> _pill3;
  late final Animation<double> _pill4;
  late final Animation<double> _exitFade;
  late final String _languageCode;
  bool _canContinue = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    final resolvedLocale =
        ref.read(localeProvider) ?? resolveDriverDeviceLocale();
    final lang = resolvedLocale.languageCode;
    _languageCode = kDriverBrandMomentCopyByLanguage.containsKey(lang)
        ? lang
        : driverFallbackLocale.languageCode;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    );

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOutCubic),
    );
    _pill1 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.20, 0.46, curve: Curves.easeOutCubic),
    );
    _pill2 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.34, 0.58, curve: Curves.easeOutCubic),
    );
    _pill3 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.48, 0.72, curve: Curves.easeOutCubic),
    );
    _pill4 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.62, 0.88, curve: Curves.easeOutCubic),
    );
    _exitFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.84, 1.00, curve: Curves.easeIn),
    );

    _ctrl.forward().then((_) => _onIntroFinished());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(appPublicLinks.refresh(force: true));
      if (HeyCabySupabase.client.auth.currentSession != null) {
        unawaited(ref.read(driverRuntimeServiceProvider).fetchRuntime());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onIntroFinished() async {
    if (!mounted) return;
    final session = HeyCabySupabase.client.auth.currentSession;
    if (session == null) {
      context.go('/login');
      return;
    }
    setState(() => _canContinue = true);
  }

  Future<void> _continueToHome() async {
    if (!mounted || _navigating) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(HapticFeedback.lightImpact());
    }
    _navigating = true;
    try {
      await navigateDriverAfterAuth(
        ref: ref,
        router: appRouter,
        context: context,
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  DriverBrandMomentCopy get _copy =>
      kDriverBrandMomentCopyByLanguage[_languageCode] ??
      kDriverBrandMomentCopyByLanguage[driverFallbackLocale.languageCode]!;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  double _opacity(Animation<double> anim) => anim.value.clamp(0.0, 1.0);

  double _slide(Animation<double> anim) =>
      (1.0 - anim.value.clamp(0.0, 1.0)) * 14.0;

  @override
  Widget build(BuildContext context) {
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final exitOpacity =
            _canContinue ? 1.0 : (1.0 - _exitFade.value).clamp(0.0, 1.0);
        final logoScale = 0.88 + 0.12 * _logoFade.value.clamp(0.0, 1.0);
        final pulse = (sin(_ctrl.value * 2 * pi * 1.2) + 1) * 0.5;
        final glowOpacity = (0.08 + pulse * 0.12) * exitOpacity;

        return DriverBrandMomentBody(
          typography: typography,
          copy: _copy,
          isIOS: _isIOS,
          exitOpacity: exitOpacity,
          logoFade: _logoFade.value,
          logoScale: logoScale,
          glowOpacity: glowOpacity,
          pillar1Opacity: _opacity(_pill1),
          pillar1Slide: _slide(_pill1),
          pillar2Opacity: _opacity(_pill2),
          pillar2Slide: _slide(_pill2),
          pillar3Opacity: _opacity(_pill3),
          pillar3Slide: _slide(_pill3),
          pillar4Opacity: _opacity(_pill4),
          pillar4Slide: _slide(_pill4),
          canContinue: _canContinue,
          loadingProgress: _ctrl.value,
          onContinue: _continueToHome,
        );
      },
    );
  }
}
