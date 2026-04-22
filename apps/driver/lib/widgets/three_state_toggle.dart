import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/driver_platform_fee_gate.dart';
import '../services/sound_service.dart';
import '../l10n/driver_strings.dart';
import '../utils/driver_go_online_policy.dart';
import 'package:heycaby_api/heycaby_api.dart';

enum DriverAvailabilityStatus {
  offline,
  onBreak,
  available,
}

class ThreeStateToggle extends ConsumerStatefulWidget {
  const ThreeStateToggle({
    super.key,
    required this.currentStatus,
  });

  final DriverAvailabilityStatus currentStatus;

  @override
  ConsumerState<ThreeStateToggle> createState() => _ThreeStateToggleState();
}

class _ThreeStateToggleState extends ConsumerState<ThreeStateToggle>
    with SingleTickerProviderStateMixin {
  late double _thumbPosition; // 0.0 = offline, 0.5 = break, 1.0 = online
  bool _isDragging = false;
  late AnimationController _controller;
  late Animation<double> _snapAnimation;
  DriverAvailabilityStatus? _lastDragHapticStatus;

  @override
  void initState() {
    super.initState();
    _thumbPosition = _statusToPosition(widget.currentStatus);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant ThreeStateToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus && !_isDragging) {
      setState(() {
        _thumbPosition = _statusToPosition(widget.currentStatus);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _statusToPosition(DriverAvailabilityStatus s) {
    switch (s) {
      case DriverAvailabilityStatus.available:
        return 1.0;
      case DriverAvailabilityStatus.onBreak:
        return 0.5;
      case DriverAvailabilityStatus.offline:
        return 0.0;
    }
  }

  DriverAvailabilityStatus _positionToStatus(double p) {
    if (p > 0.66) return DriverAvailabilityStatus.available;
    if (p > 0.33) return DriverAvailabilityStatus.onBreak;
    return DriverAvailabilityStatus.offline;
  }

  Color _colorForPosition(HeyCabyColorTokens colors, double p) {
    // Off line = red, On break = amber, Online = green.
    if (p > 0.66) return colors.success;
    if (p > 0.33) return colors.warning;
    return colors.error;
  }

  Future<void> _onStatusSnapped(DriverAvailabilityStatus newStatus) async {
    final driverData = ref.read(driverStateProvider);
    final isGoingOffline = newStatus == DriverAvailabilityStatus.offline &&
        (driverData.appState == DriverAppState.onlineAvailable ||
            driverData.appState == DriverAppState.onBreak);

    if (newStatus == DriverAvailabilityStatus.available) {
      final messenger = ScaffoldMessenger.of(context);
      final compliant = await ref.read(driverComplianceProvider.future);
      final isReviewAccount =
          HeyCabySupabase.client.auth.currentUser?.userMetadata?['review_account'] ==
              true;
      if (!driverMayGoOnline(compliant, isReviewAccount: isReviewAccount)) {
        if (!mounted) return;
        final msg = driverLicenceAwaitingManualReview(compliant)
            ? DriverStrings.onlineBlockedLicenseReview
            : DriverStrings.onlineBlockedCompliance;
        messenger.showSnackBar(SnackBar(content: Text(msg)));
        setState(() {
          _thumbPosition = _statusToPosition(widget.currentStatus);
        });
        return;
      }
      final feeOk = await ensureDriverPlatformFeeAllowsOnline(context, ref);
      if (!feeOk) {
        if (!mounted) return;
        setState(() {
          _thumbPosition = _statusToPosition(widget.currentStatus);
        });
        return;
      }
    }

    if (isGoingOffline) {
      final stats = ref.read(driverShiftStatsProvider).valueOrNull;
      final onlineMinutes = stats?.shiftStartAt != null
          ? DateTime.now().difference(stats!.shiftStartAt!).inMinutes
          : (stats?.shiftTotalOnlineMinutes ?? 0);
      final ridesToday = stats?.shiftRidesToday ?? 0;
      if (onlineMinutes >= 30) {
        final confirmed = await _showEndShiftDialog(
          context,
          onlineMinutes: onlineMinutes,
          ridesToday: ridesToday,
        );
        if (!confirmed) {
          setState(() {
            _thumbPosition =
                _statusToPosition(DriverAvailabilityStatus.available);
          });
          return;
        }
      }
    }

    final api = ref.read(driverApiProvider);
    try {
      final position = await requestAndGetLocation();
      if (!mounted) return;
      await api.setStatus(
        status: switch (newStatus) {
          DriverAvailabilityStatus.available => 'available',
          DriverAvailabilityStatus.onBreak => 'on_break',
          DriverAvailabilityStatus.offline => 'offline',
        },
        lat: position?.latitude,
        lng: position?.longitude,
      );

      if (!mounted) return;
      switch (newStatus) {
        case DriverAvailabilityStatus.available:
          HapticFeedback.heavyImpact();
          SoundService().playNotification();
          break;
        case DriverAvailabilityStatus.onBreak:
          HapticFeedback.mediumImpact();
          break;
        case DriverAvailabilityStatus.offline:
          HapticFeedback.lightImpact();
          break;
      }
      final notifier = ref.read(driverStateProvider.notifier);
      switch (newStatus) {
        case DriverAvailabilityStatus.available:
          notifier.setStatus(DriverAppState.onlineAvailable);
          final id = await ref.read(driverIdProvider.future);
          if (id != null) {
            await ref
                .read(driverShiftSessionServiceProvider)
                .ensureShiftSessionStarted(id);
          }
          ref.invalidate(driverShiftStatsProvider);
          break;
        case DriverAvailabilityStatus.onBreak:
          notifier.setStatus(DriverAppState.onBreak);
          ref.invalidate(driverShiftStatsProvider);
          break;
        case DriverAvailabilityStatus.offline:
          notifier.setStatus(DriverAppState.offline);
          final id = await ref.read(driverIdProvider.future);
          if (id != null) {
            await ref
                .read(driverShiftSessionServiceProvider)
                .endShiftSession(id);
          }
          ref.invalidate(driverShiftStatsProvider);
          break;
      }
    } catch (_) {
      if (!mounted) return;
      // Snap back to previous status on failure
      setState(() {
        _thumbPosition = _statusToPosition(widget.currentStatus);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverStrings.endShiftDetail),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool> _showEndShiftDialog(
    BuildContext context, {
    required int onlineMinutes,
    required int ridesToday,
  }) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final hours = onlineMinutes ~/ 60;
    final minutes = onlineMinutes % 60;
    final durationText = '${hours}h ${minutes.toString().padLeft(2, '0')}m';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          DriverStrings.endShiftConfirm,
          style: typo.titleMedium,
        ),
        content: Text(
          DriverStrings.endShiftDetail
              .replaceFirst('X hours', durationText)
              .replaceFirst('Y rides', '$ridesToday rides'),
          style: typo.bodyMedium.copyWith(color: colors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(DriverStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.card,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(DriverStrings.endShift),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _animateToPosition(double target) {
    _snapAnimation = Tween<double>(
      begin: _thumbPosition,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    )..addListener(() {
        setState(() {
          _thumbPosition = _snapAnimation.value;
        });
      });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbDiameter = 38.0;
        const trackPadding = 4.0;
        final trackWidth = width - trackPadding * 2 - thumbDiameter;

        double positionToDx(double position) {
          return trackPadding + position * trackWidth;
        }

        final thumbDx = positionToDx(_thumbPosition);

        final labelStyle =
            typo.bodySmall.copyWith(fontSize: 13, letterSpacing: -0.1);
        final dragStatus = _positionToStatus(_thumbPosition);
        final activeColor = _colorForPosition(colors, _thumbPosition);
        final trackFill = colors.surface;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onHorizontalDragStart: (_) {
                _isDragging = true;
                _lastDragHapticStatus = _positionToStatus(_thumbPosition);
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final delta = details.delta.dx / trackWidth;
                  _thumbPosition = (_thumbPosition + delta).clamp(0.0, 1.0);
                });
                final newStatus = _positionToStatus(_thumbPosition);
                if (newStatus != _lastDragHapticStatus) {
                  _lastDragHapticStatus = newStatus;
                  HapticFeedback.selectionClick();
                }
              },
              onHorizontalDragEnd: (_) async {
                _isDragging = false;
                final snappedStatus = _positionToStatus(_thumbPosition);
                final targetPos = _statusToPosition(snappedStatus);
                _animateToPosition(targetPos);
                await _onStatusSnapped(snappedStatus);
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: trackFill,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: colors.text.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned.fill(
                      child: AnimatedAlign(
                        duration: _isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        alignment:
                            dragStatus == DriverAvailabilityStatus.offline
                                ? Alignment.centerLeft
                                : dragStatus == DriverAvailabilityStatus.onBreak
                                    ? Alignment.center
                                    : Alignment.centerRight,
                        child: Container(
                          width: width / 3,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colors.card.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colors.text.withValues(alpha: 0.04),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.text.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: thumbDx,
                      top: 7,
                      child: Container(
                        width: thumbDiameter,
                        height: thumbDiameter,
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.text.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.text.withValues(alpha: 0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DriverStrings.offline,
                  style: labelStyle.copyWith(
                    color:
                        widget.currentStatus == DriverAvailabilityStatus.offline
                            ? colors.error
                            : colors.textSoft.withValues(alpha: 0.75),
                    fontWeight:
                        widget.currentStatus == DriverAvailabilityStatus.offline
                            ? FontWeight.w600
                            : FontWeight.w400,
                  ),
                ),
                Text(
                  DriverStrings.onBreak,
                  style: labelStyle.copyWith(
                    color:
                        widget.currentStatus == DriverAvailabilityStatus.onBreak
                            ? colors.warning
                            : colors.textSoft.withValues(alpha: 0.75),
                    fontWeight:
                        widget.currentStatus == DriverAvailabilityStatus.onBreak
                            ? FontWeight.w600
                            : FontWeight.w400,
                  ),
                ),
                Text(
                  DriverStrings.online,
                  style: labelStyle.copyWith(
                    color: widget.currentStatus ==
                            DriverAvailabilityStatus.available
                        ? colors.success
                        : colors.textSoft.withValues(alpha: 0.75),
                    fontWeight: widget.currentStatus ==
                            DriverAvailabilityStatus.available
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).animate().fadeIn(duration: 250.ms);
  }
}
