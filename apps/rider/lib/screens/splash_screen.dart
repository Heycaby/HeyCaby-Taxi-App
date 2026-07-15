import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heycaby_api/heycaby_api.dart' show appPublicLinks;
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_matching_variant.dart';
import '../providers/location_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/rider_locale_provider.dart';
import '../services/rider_home_banners_service.dart';
import '../services/rider_runtime_config_service.dart';

/// First launch: short brand splash (max ~3s). Returning users skip to location flow.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _startupStepTimeout = Duration(seconds: 3);

  late final AnimationController _motion;
  bool _showBrandSplash = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    String route = '/home';

    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

      if (isFirstLaunch) {
        if (mounted) setState(() => _showBrandSplash = true);
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        await prefs.setBool('is_first_launch', false);
      }

      // Never trigger an OS permission prompt from splash. We only prewarm location
      // if permission was already granted before. Startup work must never trap the
      // rider on splash; Home can finish loading any slow network state.
      await ref
          .read(locationProvider.notifier)
          .refreshIfPermitted()
          .timeout(_startupStepTimeout, onTimeout: () {});
      final localeTag = ref.read(riderAppLocaleTagProvider);
      await Future.wait<dynamic>([
        riderRuntimeConfig.refresh(force: true),
        appPublicLinks.refresh(force: true),
        riderHomeBannersService.refresh(
          locale: localeTag,
          force: true,
        ),
      ]).timeout(_startupStepTimeout, onTimeout: () => const <dynamic>[]);

      if (!mounted) return;
      route = await _checkForActiveRide().timeout(
            _startupStepTimeout,
            onTimeout: () => null,
          ) ??
          '/home';
    } catch (_) {
      // Keep startup resilient; app falls back to local defaults.
    }

    if (!mounted) return;
    context.go(route);
  }

  Future<String?> _checkForActiveRide() async {
    try {
      final restored = await ref
          .read(rideRequestProvider.notifier)
          .tryRestoreActiveRideRequest();
      if (!restored) return null;
      final activeRide = ref.read(rideRequestProvider);
      final status = activeRide.status ?? '';

      switch (status) {
        case 'pending':
        case 'bidding':
          final bm = activeRide.bookingMode;
          return rideMatchingVariantForBookingModeString(bm).routePath;
        case 'accepted':
        case 'assigned':
        case 'driver_found':
        case 'driver_en_route':
        case 'driver_arrived':
        case 'in_progress':
          return '/active';
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final l10n = AppLocalizations.of(context);

    if (_showBrandSplash) {
      return _RiderSplashBrandMoment(
        colors: colors,
        tagline: l10n.riderSplashTagline,
        motion: _motion,
      );
    }

    return _RiderSplashBrandMoment(
      colors: colors,
      tagline: l10n.riderSplashTagline,
      motion: _motion,
      compact: true,
    );
  }
}

class _RiderSplashBrandMoment extends StatelessWidget {
  const _RiderSplashBrandMoment({
    required this.colors,
    required this.tagline,
    required this.motion,
    this.compact = false,
  });

  final HeyCabyColorTokens colors;
  final String tagline;
  final Animation<double> motion;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(motion.value);
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -2 + (4 * t)),
                      child: _HeyCabyWordmark(
                        accent: colors.accent,
                        text: colors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tagline,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textMid,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _MinimalProgressBar(
                      color: colors.accent,
                      track: colors.border,
                      progress: motion.value,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeyCabyWordmark extends StatelessWidget {
  const _HeyCabyWordmark({
    required this.accent,
    required this.text,
  });

  final Color accent;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Hey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: text,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'Caby',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalProgressBar extends StatelessWidget {
  const _MinimalProgressBar({
    required this.color,
    required this.track,
    required this.progress,
  });

  final Color color;
  final Color track;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 128,
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track.withValues(alpha: 0.5)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (0.22 + 0.78 * progress).clamp(0.22, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
