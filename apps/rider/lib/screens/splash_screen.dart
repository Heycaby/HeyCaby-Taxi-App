import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../providers/location_provider.dart';
import '../services/rider_runtime_config_service.dart';
import '../services/stale_ride_cleanup.dart';

/// First launch: short brand splash (max ~3s). Returning users skip to location flow.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _showBrandSplash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      if (mounted) setState(() => _showBrandSplash = true);
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await prefs.setBool('is_first_launch', false);
    }

    // Never trigger an OS permission prompt from splash. We only prewarm location
    // if permission was already granted before.
    await ref.read(locationProvider.notifier).refreshIfPermitted();
    try {
      await riderRuntimeConfig.refresh(force: true);
    } catch (_) {
      // Keep startup resilient; app falls back to local defaults.
    }
    if (!mounted) return;

    final activeRoute = await _checkForActiveRide();
    if (!mounted) return;
    context.go(activeRoute ?? '/home');
  }

  Future<String?> _checkForActiveRide() async {
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      if (!identity.hasSession || identity.riderToken == null) return null;

      final activeRide = await HeyCabySupabase.client
          .from('ride_requests')
          .select('id, status, created_at, booking_mode')
          .eq('rider_token', identity.riderToken!)
          .inFilter('status', [
            'pending',
            'bidding',
            'assigned',
            'accepted',
            'driver_found',
            'driver_arrived',
            'in_progress',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeRide == null) return null;

      final status = activeRide['status'] as String;
      final createdRaw = activeRide['created_at'];
      final createdAt = createdRaw == null
          ? null
          : DateTime.tryParse(createdRaw.toString());

      // Do not reopen Searching for hours-old open requests — same 30 min window as notify-me.
      if ((status == 'pending' || status == 'bidding') &&
          createdAt != null &&
          DateTime.now().difference(createdAt) > kRiderDriverSearchWindow) {
        final id = activeRide['id'] as String?;
        if (id != null) {
          unawaited(
            cancelExpiredRiderOpenRide(
              rideId: id,
              riderToken: identity.riderToken!,
            ),
          );
        }
        return null;
      }

      switch (status) {
        case 'pending':
        case 'bidding':
          final bm = activeRide['booking_mode'] as String?;
          return rideMatchingVariantForBookingModeString(bm).routePath;
        case 'accepted':
        case 'assigned':
        case 'driver_found':
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
    const amber = Color(0xFFF4A800);
    const deep = Color(0xFF0B0804);

    if (_showBrandSplash) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: amber,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'C',
                        style: GoogleFonts.syne(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: deep,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'hey',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: colors.text.withValues(alpha: 0.9),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'caby',
                          style: GoogleFonts.syne(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: amber,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.riderSplashTagline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: colors.textMid,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 140,
                    height: 3,
                    decoration: BoxDecoration(
                      color: amber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
