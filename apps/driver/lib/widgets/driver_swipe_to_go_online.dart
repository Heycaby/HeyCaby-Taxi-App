import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/driver_platform_fee_gate.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_policy.dart';

/// Slide-to-activate control for going online. Prevents accidental taps.
class DriverSwipeToGoOnline extends ConsumerStatefulWidget {
  const DriverSwipeToGoOnline({
    super.key,
    required this.colors,
    required this.typo,
    this.onComplete,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onComplete;

  @override
  ConsumerState<DriverSwipeToGoOnline> createState() =>
      _DriverSwipeToGoOnlineState();
}

class _DriverSwipeToGoOnlineState extends ConsumerState<DriverSwipeToGoOnline> {
  double _dragOffset = 0;
  bool _isLoading = false;
  bool _completed = false;

  Future<void> _onSlideComplete() async {
    if (_isLoading || _completed) return;
    setState(() => _isLoading = true);
    try {
      final position = await requestAndGetLocation();
      if (!mounted) return;
      if (position == null) {
        _showLocationRequiredDialog();
        setState(() => _dragOffset = 0);
        return;
      }

      final compliant = await ref.read(driverComplianceProvider.future);
      final isReviewAccount =
          HeyCabySupabase.client.auth.currentUser?.userMetadata?['review_account'] ==
              true;
      if (!driverMayGoOnline(compliant, isReviewAccount: isReviewAccount)) {
        if (!mounted) return;
        final msg = driverLicenceAwaitingManualReview(compliant)
            ? DriverStrings.onlineBlockedLicenseReview
            : DriverStrings.onlineBlockedCompliance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() => _dragOffset = 0);
        return;
      }

      final feeOk = await ensureDriverPlatformFeeAllowsOnline(context, ref);
      if (!feeOk) {
        if (mounted) setState(() => _dragOffset = 0);
        return;
      }

      await ref.read(driverApiProvider).setStatus(
            status: 'available',
            lat: position.latitude,
            lng: position.longitude,
          );
      if (!mounted) return;
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
      final driverId = await ref.read(driverIdProvider.future);
      if (driverId != null) {
        await ref.read(driverShiftSessionServiceProvider).ensureShiftSessionStarted(driverId);
      }
      ref.invalidate(driverShiftStatsProvider);
      SoundService().playNotification();
      setState(() => _completed = true);
      widget.onComplete?.call();
    } catch (e, _) {
      if (mounted) {
        setState(() => _dragOffset = 0);
        final msg = _errorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorMessage(dynamic e) {
    if (kDebugMode) debugPrint('Go-online error: $e');
    if (e is DioException) {
      final res = e.response;
      final data = res?.data;
      if (data is Map && data['code'] == 'PAYMENT_REQUIRED') {
        return DriverStrings.platformFeeStillPending;
      }
      if (res?.statusCode == 400) {
        return 'Server rejected request. Check that your driver profile is complete.';
      }
    }
    return 'Failed to go online. Please try again.';
  }

  void _showLocationRequiredDialog() {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.mapPinOff, color: colors.textSoft),
            const SizedBox(width: 12),
            Text(DriverStrings.locationRequired, style: typo.titleMedium),
          ],
        ),
        content: Text(
          DriverStrings.locationRequiredMessage,
          style: typo.bodyMedium.copyWith(color: colors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(DriverStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: Text(DriverStrings.enableLocation),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final pos = await requestAndGetLocation();
              if (pos != null && mounted) _onSlideComplete();
            },
            child: Text(DriverStrings.tryAgain),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final thumbSize = 56.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxSlide = trackWidth - thumbSize - 8;
        final progress = maxSlide > 0 ? (_dragOffset / maxSlide).clamp(0.0, 1.0) : 0.0;
        final triggered = progress >= 0.85;

        return GestureDetector(
          onHorizontalDragStart: _isLoading ? null : (_) {},
          onHorizontalDragUpdate: _isLoading
              ? null
              : (d) {
                  setState(() {
                    _dragOffset =
                        (_dragOffset + d.delta.dx).clamp(0.0, maxSlide);
                    if (maxSlide > 0 && _dragOffset >= maxSlide * 0.85) {
                      _onSlideComplete();
                    }
                  });
                },
          onHorizontalDragEnd: _isLoading
              ? null
              : (_) {
                  if (!triggered) setState(() => _dragOffset = 0);
                },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Text(
                    DriverStrings.slideToGoOnline,
                    style: typo.bodyMedium.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Positioned(
                  left: 4 + _dragOffset,
                  top: 4,
                  child: Container(
                    width: thumbSize - 8,
                    height: thumbSize - 8,
                    decoration: BoxDecoration(
                      color: triggered ? colors.success : colors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                triggered ? colors.card : colors.onAccent,
                              ),
                            ),
                          )
                        : Icon(
                            triggered ? AppIcons.check : AppIcons.chevronRight,
                            color: triggered ? colors.card : colors.onAccent,
                            size: 26,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
