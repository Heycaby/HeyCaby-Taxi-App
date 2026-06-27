import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../l10n/driver_strings.dart';
import '../utils/driver_go_online_runtime_action.dart';
import '../utils/driver_network_guard.dart';
import '../utils/driver_runtime_refresh.dart';
import '../widgets/driver_go_online_guidance_sheet.dart';
import 'driver_shift_timer_widget.dart';
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
  bool _didStartDragHaptic = false;

  Future<void> _showBreakWidgetPopout() async {
    final colors = ref.read(colorsProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.of(ctx).padding.bottom + 12,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: const DriverShiftTimerWidget(),
          ),
        ),
      ),
    );
  }

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
    if (_isDragging) return;
    final expectedPosition = _statusToPosition(widget.currentStatus);
    if (oldWidget.currentStatus != widget.currentStatus ||
        (_thumbPosition - expectedPosition).abs() > 0.01) {
      _resetThumbToPosition(widget.currentStatus);
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
    if (!await ensureDriverNetworkForAction(context, ref)) {
      _resetThumbToCurrentStatus();
      return;
    }

    final driverData = ref.read(driverStateProvider);
    final isGoingOffline = newStatus == DriverAvailabilityStatus.offline &&
        (driverData.appState == DriverAppState.onlineAvailable ||
            driverData.appState == DriverAppState.onBreak);

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
          _resetThumbToPosition(DriverAvailabilityStatus.available);
          return;
        }
      }
    }

    final api = ref.read(driverApiProvider);
    try {
      final position = await requestAndGetLocation();
      if (!mounted) return;

      if (newStatus == DriverAvailabilityStatus.available) {
        if (position == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DriverStrings.locationRequiredMessage)),
          );
          HapticService.mediumTap();
          SoundService().playActionBlocked();
          _resetThumbToCurrentStatus();
          return;
        }
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
          _resetThumbToCurrentStatus();
          return;
        }
        if (!attempt.succeeded) {
          _resetThumbToCurrentStatus();
          return;
        }
        if (!mounted) return;
        HapticService.heavyTap();
        SoundService().playStatusOnline();
        final notifier = ref.read(driverStateProvider.notifier);
        notifier.setStatus(DriverAppState.onlineAvailable);
        _resetThumbToPosition(DriverAvailabilityStatus.available);
        final id = await ref.read(driverIdProvider.future);
        if (id != null) {
          await ref
              .read(driverShiftSessionServiceProvider)
              .ensureShiftSessionStarted(id);
        }
        ref.invalidate(driverShiftStatsProvider);
        unawaited(refreshDriverRuntime(ref));
        return;
      }

      final statusStr = newStatus == DriverAvailabilityStatus.onBreak
          ? 'on_break'
          : 'offline';
      await api.setStatus(
        status: statusStr,
        lat: position?.latitude,
        lng: position?.longitude,
      );

      if (!mounted) return;
      final notifier = ref.read(driverStateProvider.notifier);
      if (newStatus == DriverAvailabilityStatus.onBreak) {
        HapticService.mediumTap();
        SoundService().playStatusOnBreak();
        notifier.setStatus(DriverAppState.onBreak);
        ref.invalidate(driverShiftStatsProvider);
        unawaited(refreshDriverRuntime(ref));
        if (mounted) {
          unawaited(_showBreakWidgetPopout());
        }
      } else {
        HapticService.lightTap();
        SoundService().playStatusOffline();
        notifier.setStatus(DriverAppState.offline);
        final id = await ref.read(driverIdProvider.future);
        if (id != null) {
          await ref
              .read(driverShiftSessionServiceProvider)
              .endShiftSession(id);
        }
        ref.invalidate(driverShiftStatsProvider);
        unawaited(refreshDriverRuntime(ref));
      }
    } catch (e) {
      if (!mounted) return;
      _resetThumbToCurrentStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DriverStrings.goOnlineFailed} ($e)'),
          duration: const Duration(seconds: 4),
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

  void _resetThumbToPosition(DriverAvailabilityStatus status) {
    _controller.stop();
    _controller.reset();
    setState(() {
      _thumbPosition = _statusToPosition(status);
    });
  }

  void _resetThumbToCurrentStatus() {
    _resetThumbToPosition(widget.currentStatus);
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
        const thumbDiameter = 44.0;
        const trackPadding = 5.0;
        final trackWidth = width - trackPadding * 2 - thumbDiameter;

        double positionToDx(double position) {
          return trackPadding + position * trackWidth;
        }

        final thumbDx = positionToDx(_thumbPosition);

        final labelStyle =
            typo.bodySmall.copyWith(fontSize: 13, letterSpacing: 0.2);
        final dragStatus = _positionToStatus(_thumbPosition);
        final activeColor = _colorForPosition(colors, _thumbPosition);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onHorizontalDragStart: (_) {
                _isDragging = true;
                if (!_didStartDragHaptic) {
                  HapticService.mediumTap();
                  _didStartDragHaptic = true;
                }
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
                  HapticService.mediumTap();
                }
              },
              onHorizontalDragEnd: (_) async {
                _isDragging = false;
                _didStartDragHaptic = false;
                final snappedStatus = _positionToStatus(_thumbPosition);
                final goingOnline =
                    snappedStatus == DriverAvailabilityStatus.available;
                if (!goingOnline) {
                  _animateToPosition(_statusToPosition(snappedStatus));
                }
                await _onStatusSnapped(snappedStatus);
                if (!mounted) return;
                if (goingOnline &&
                    widget.currentStatus != DriverAvailabilityStatus.available) {
                  _resetThumbToCurrentStatus();
                }
              },
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  gradient: LinearGradient(
                    colors: [
                      colors.error.withValues(alpha: 0.08),
                      colors.warning.withValues(alpha: 0.06),
                      colors.success.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: colors.text.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: -8,
                    ),
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.card.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: activeColor.withValues(alpha: 0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
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
                            color: activeColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: -2,
                            ),
                            BoxShadow(
                              color: colors.text.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.55),
                                  blurRadius: 8,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ToggleLabel(
                  label: DriverStrings.offline,
                  active: widget.currentStatus == DriverAvailabilityStatus.offline,
                  activeColor: colors.error,
                  inactiveColor: colors.textSoft.withValues(alpha: 0.75),
                  style: labelStyle,
                ),
                _ToggleLabel(
                  label: DriverStrings.onBreak,
                  active: widget.currentStatus == DriverAvailabilityStatus.onBreak,
                  activeColor: colors.warning,
                  inactiveColor: colors.textSoft.withValues(alpha: 0.75),
                  style: labelStyle,
                ),
                _ToggleLabel(
                  label: DriverStrings.online,
                  active: widget.currentStatus ==
                      DriverAvailabilityStatus.available,
                  activeColor: colors.success,
                  inactiveColor: colors.textSoft.withValues(alpha: 0.75),
                  style: labelStyle,
                ),
              ],
            ),
          ],
        );
      },
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.style,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      style: style.copyWith(
        color: active ? activeColor : inactiveColor,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      child: Text(label),
    );
  }
}
