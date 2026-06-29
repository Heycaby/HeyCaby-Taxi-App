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
import '../theme/app_icons.dart';
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
  bool _isWritingStatus = false;

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

  Color _colorForStatus(
    HeyCabyColorTokens colors,
    DriverAvailabilityStatus status,
  ) {
    return switch (status) {
      DriverAvailabilityStatus.available => colors.success,
      DriverAvailabilityStatus.onBreak => colors.accent,
      DriverAvailabilityStatus.offline => colors.textSoft,
    };
  }

  String _hintForStatus(DriverAvailabilityStatus status) {
    return switch (status) {
      DriverAvailabilityStatus.available => 'Je bent live in jouw zone.',
      DriverAvailabilityStatus.onBreak =>
        'Je pauze is actief. Ga online om ritten te zien.',
      DriverAvailabilityStatus.offline =>
        'Ga online om live ritaanvragen in jouw zone te zien.',
    };
  }

  String _failureMessageForStatus(DriverAvailabilityStatus status) {
    return switch (status) {
      DriverAvailabilityStatus.available => DriverStrings.goOnlineFailed,
      DriverAvailabilityStatus.onBreak =>
        'Pauze starten mislukt. Controleer je verbinding en probeer opnieuw.',
      DriverAvailabilityStatus.offline =>
        'Offline gaan mislukt. Controleer je verbinding en probeer opnieuw.',
    };
  }

  Future<void> _onStatusSnapped(DriverAvailabilityStatus newStatus) async {
    if (_isWritingStatus || newStatus == widget.currentStatus) {
      _resetThumbToCurrentStatus();
      return;
    }
    if (!await ensureDriverNetworkForAction(context, ref)) {
      HapticService.error();
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
        if (!mounted) return;
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
    setState(() => _isWritingStatus = true);
    try {
      final position = await requestAndGetLocation();
      if (!mounted) return;

      if (newStatus == DriverAvailabilityStatus.available) {
        if (position == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(DriverStrings.locationRequiredMessage),
            ),
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
          await showDriverGoOnlineGuidanceSheet(context, ref,
              args: attempt.gateArgs!);
          _resetThumbToCurrentStatus();
          return;
        }
        if (!attempt.succeeded) {
          HapticService.error();
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
          await ref.read(driverShiftSessionServiceProvider).endShiftSession(id);
        }
        ref.invalidate(driverShiftStatsProvider);
        unawaited(refreshDriverRuntime(ref));
      }
    } catch (e) {
      if (!mounted) return;
      HapticService.error();
      _resetThumbToCurrentStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_failureMessageForStatus(newStatus)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isWritingStatus = false);
      }
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
            child: Text(DriverStrings.cancel),
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
        const trackPadding = 5.0;
        final trackWidth = width - trackPadding * 2;
        final segmentWidth = trackWidth / 3;

        double positionToDx(double position) {
          return trackPadding + position * (trackWidth - segmentWidth);
        }

        final thumbDx = positionToDx(_thumbPosition);

        final labelStyle = typo.bodyMedium.copyWith(
          fontSize: 15,
          letterSpacing: 0,
          height: 1,
        );
        final dragStatus = _positionToStatus(_thumbPosition);
        final confirmedStatus = widget.currentStatus;
        final activeColor = _colorForStatus(colors, dragStatus);
        final confirmedColor = _colorForStatus(colors, confirmedStatus);
        final enabled = !_isWritingStatus;

        Future<void> submitStatus(DriverAvailabilityStatus status) async {
          if (!enabled) return;
          HapticService.selectionClick();
          _animateToPosition(_statusToPosition(status));
          await _onStatusSnapped(status);
        }

        return Opacity(
          opacity: enabled ? 1 : 0.72,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.95),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -10,
                ),
                BoxShadow(
                  color: colors.success.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: confirmedColor.withValues(alpha: 0.14),
                        border: Border.all(
                          color: confirmedColor.withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: confirmedColor.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: Icon(
                        AppIcons.navHome,
                        color: confirmedColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _hintForStatus(confirmedStatus),
                        style: typo.bodyLarge.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTapUp: (details) async {
                    final dx = details.localPosition.dx.clamp(0.0, width);
                    final segment = (dx / (width / 3)).floor().clamp(0, 2);
                    final status = switch (segment) {
                      0 => DriverAvailabilityStatus.offline,
                      1 => DriverAvailabilityStatus.onBreak,
                      _ => DriverAvailabilityStatus.available,
                    };
                    await submitStatus(status);
                  },
                  onHorizontalDragStart: (_) {
                    if (!enabled) return;
                    _isDragging = true;
                    if (!_didStartDragHaptic) {
                      HapticService.selectionClick();
                      _didStartDragHaptic = true;
                    }
                    _lastDragHapticStatus = _positionToStatus(_thumbPosition);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!enabled) return;
                    setState(() {
                      final delta = details.delta.dx / trackWidth;
                      _thumbPosition = (_thumbPosition + delta).clamp(0.0, 1.0);
                    });
                    final newStatus = _positionToStatus(_thumbPosition);
                    if (newStatus != _lastDragHapticStatus) {
                      _lastDragHapticStatus = newStatus;
                      HapticService.selectionClick();
                    }
                  },
                  onHorizontalDragEnd: (_) async {
                    if (!enabled) return;
                    _isDragging = false;
                    _didStartDragHaptic = false;
                    final snappedStatus = _positionToStatus(_thumbPosition);
                    _animateToPosition(_statusToPosition(snappedStatus));
                    await _onStatusSnapped(snappedStatus);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: LinearGradient(
                        colors: [
                          activeColor.withValues(alpha: 0.08),
                          colors.surface.withValues(alpha: 0.88),
                          colors.card.withValues(alpha: 0.96),
                        ],
                      ),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.20),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
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
                            alignment: dragStatus ==
                                    DriverAvailabilityStatus.offline
                                ? Alignment.centerLeft
                                : dragStatus == DriverAvailabilityStatus.onBreak
                                    ? Alignment.center
                                    : Alignment.centerRight,
                            child: Container(
                              width: width / 3,
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  activeColor.withValues(alpha: 0.10),
                                  colors.card,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: activeColor.withValues(alpha: 0.34),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.card.withValues(alpha: 0.92),
                                    blurRadius: 1,
                                    offset: const Offset(0, -1),
                                  ),
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _SegmentButton(
                              label: DriverStrings.offline,
                              semanticsLabel: 'Driver status offline',
                              active: dragStatus ==
                                  DriverAvailabilityStatus.offline,
                              activeColor: activeColor,
                              inactiveColor: colors.textMid,
                              dotColor: colors.textSoft,
                              style: labelStyle,
                            ),
                            _SegmentButton(
                              label: DriverStrings.onBreak,
                              semanticsLabel: 'Driver status break',
                              active: dragStatus ==
                                  DriverAvailabilityStatus.onBreak,
                              activeColor: activeColor,
                              inactiveColor: colors.textMid,
                              dotColor: colors.accent,
                              style: labelStyle,
                            ),
                            _SegmentButton(
                              label: DriverStrings.online,
                              semanticsLabel: 'Driver status online',
                              active: dragStatus ==
                                  DriverAvailabilityStatus.available,
                              activeColor: activeColor,
                              inactiveColor: colors.textMid,
                              dotColor: colors.success,
                              style: labelStyle,
                            ),
                          ],
                        ),
                        if (_isWritingStatus)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            left: thumbDx + segmentWidth - 34,
                            top: 21,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  activeColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.semanticsLabel,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.dotColor,
    required this.style,
  });

  final String label;
  final String semanticsLabel;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final Color dotColor;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticsLabel,
        selected: active,
        button: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: active ? 6 : 0,
                  height: active ? 6 : 0,
                  margin: EdgeInsets.only(right: active ? 5 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.26),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    style: style.copyWith(
                      color: active ? activeColor : inactiveColor,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
