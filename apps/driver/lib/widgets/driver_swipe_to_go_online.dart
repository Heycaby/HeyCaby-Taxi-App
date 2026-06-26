import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../theme/driver_motion.dart';
import '../theme/driver_motion_presets.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_runtime_action.dart';
import 'driver_go_online_guidance_sheet.dart';

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
  bool _didStartDragHaptic = false;
  bool _didReachTriggerHaptic = false;

  Future<void> _onSlideComplete() async {
    if (_isLoading || _completed) return;
    setState(() => _isLoading = true);
    try {
      final position = await requestAndGetLocation();
      if (!mounted) return;
      if (position == null) {
        _showLocationRequiredDialog();
        HapticService.mediumTap();
        SoundService().playActionBlocked();
        setState(() => _dragOffset = 0);
        return;
      }

      if (!mounted) return;
      final attempt = await attemptDriverGoOnline(
        context: context,
        ref: ref,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (attempt.isBlocked) {
        HapticService.mediumTap();
        SoundService().playActionBlocked();
        await showDriverGoOnlineGuidanceSheet(context, ref, args: attempt.gateArgs!);
        if (mounted) setState(() => _dragOffset = 0);
        return;
      }
      if (!attempt.succeeded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DriverStrings.goOnlineFailed)),
          );
        }
        setState(() => _dragOffset = 0);
        return;
      }
      if (!mounted) return;
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
      final driverId = await ref.read(driverIdProvider.future);
      if (driverId != null) {
        await ref.read(driverShiftSessionServiceProvider).ensureShiftSessionStarted(driverId);
      }
      ref.invalidate(driverShiftStatsProvider);
      HapticService.heavyTap();
      SoundService().playStatusOnline();
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
    return DriverStrings.failedToGoOnline;
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
    const thumbSize = 56.0;

    if (_completed) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.success.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.check, color: colors.success, size: 22),
            const SizedBox(width: 10),
            Text(
              DriverStrings.youAreOnline,
              style: typo.bodyLarge.copyWith(
                color: colors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ).driverSuccessPop();
    }

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
                    if (!_didStartDragHaptic) {
                      HapticService.mediumTap();
                      _didStartDragHaptic = true;
                    }
                    if (maxSlide > 0 && _dragOffset >= maxSlide * 0.85 && !_didReachTriggerHaptic) {
                      _didReachTriggerHaptic = true;
                      HapticService.heavyTap();
                      _onSlideComplete();
                    }
                  });
                },
          onHorizontalDragEnd: _isLoading
              ? null
              : (_) {
                  _didStartDragHaptic = false;
                  _didReachTriggerHaptic = false;
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: DriverMotion.fast,
                    curve: DriverMotion.standardCurve,
                    width: trackWidth * progress,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(
                        alpha: 0.12 + progress * 0.18,
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
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
                  child: AnimatedContainer(
                    duration: DriverMotion.fast,
                    curve: DriverMotion.standardCurve,
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
