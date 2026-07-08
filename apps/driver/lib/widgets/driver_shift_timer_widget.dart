import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_runtime_action.dart';
import 'driver_go_online_guidance_sheet.dart';
import 'driver_shift_arc_painter.dart';

const _shiftArcMinutes = 8 * 60;

/// Sticky shift card: docks above the bottom sheet when online — 8h arc, stats, Pauze/Hervat/Stop.
class DriverShiftTimerWidget extends ConsumerStatefulWidget {
  const DriverShiftTimerWidget({super.key});

  @override
  ConsumerState<DriverShiftTimerWidget> createState() =>
      _DriverShiftTimerWidgetState();
}

class _DriverShiftTimerWidgetState
    extends ConsumerState<DriverShiftTimerWidget> {
  Timer? _ticker;
  bool _busy = false;
  int _tickCount = 0;
  DriverAppState? _lastObservedState;
  DateTime? _localOnlineStartedAt;
  DateTime? _localBreakStartedAt;
  DateTime? _breakTargetStartedAt;
  int? _breakTargetMinutes;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _tickCount++);
      if (_tickCount % 30 == 0) {
        ref.invalidate(driverShiftStatsProvider);
        ref.invalidate(driverEarningsProvider);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _setStatus(String status, DriverAppState next) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pos = await requestAndGetLocation();
      await ref.read(driverApiProvider).setStatus(
            status: status,
            lat: pos?.latitude,
            lng: pos?.longitude,
          );
      ref.read(driverStateProvider.notifier).setStatus(next);
      if (next != DriverAppState.onBreak) {
        _breakTargetStartedAt = null;
        _breakTargetMinutes = null;
      }
      if (status == 'available') {
        SoundService().playStatusOnline();
      } else if (status == 'on_break') {
        SoundService().playStatusOnBreak();
      } else if (status == 'offline') {
        SoundService().playStatusOffline();
      } else {
        SoundService().playNotification();
      }
      ref.invalidate(driverShiftStatsProvider);
      ref.invalidate(driverEarningsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverStrings.endShiftDetail)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseAndStartBreak() async {
    final minutes = await _showBreakLengthSheet();
    if (minutes == null || !mounted) return;
    setState(() {
      _breakTargetMinutes = minutes;
      _breakTargetStartedAt = DateTime.now();
    });
    await _setStatus('on_break', DriverAppState.onBreak);
  }

  Future<int?> _showBreakLengthSheet() async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final options = <int>[5, 10, 15, 20, 30, 45];
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: colors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.shiftChooseBreak,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in options)
                      ChoiceChip(
                        label: Text(DriverStrings.shiftBreakMinutes(option)),
                        selected: option == (_breakTargetMinutes ?? 15),
                        onSelected: (_) => Navigator.pop(ctx, option),
                        selectedColor: colors.success.withValues(alpha: 0.14),
                        backgroundColor: colors.bgAlt,
                        labelStyle: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: option == (_breakTargetMinutes ?? 15)
                              ? colors.success.withValues(alpha: 0.55)
                              : colors.border,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onStop() async {
    final stats = ref.read(driverShiftStatsProvider).valueOrNull;
    final onlineMins = stats?.shiftTotalOnlineMinutes ?? 0;
    final rides = stats?.shiftRidesToday ?? 0;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: DriverStrings.endShiftConfirm,
      message: DriverStrings.endShiftDetail
          .replaceFirst(
              'X hours', '${onlineMins ~/ 60}h ${onlineMins % 60}m')
          .replaceFirst('Y rides', '$rides rides'),
      dismissLabel: DriverStrings.cancel,
      confirmLabel: DriverStrings.endShift,
      icon: Icons.power_settings_new_rounded,
      confirmDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final id = await ref.read(driverIdProvider.future);
    if (id != null) {
      await ref.read(driverShiftSessionServiceProvider).endShiftSession(id);
    }
    await _setStatus('offline', DriverAppState.offline);
  }

  Future<void> _resumeFromBreakOnline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final attempt =
          await attemptDriverGoOnlineWithLocationGuard(context, ref);
      if (!mounted) return;
      if (attempt.isBlocked) {
        await showDriverGoOnlineGuidanceSheet(context, ref,
            args: attempt.gateArgs!);
        return;
      }
      if (!attempt.succeeded) return;
      ref
          .read(driverStateProvider.notifier)
          .setStatus(DriverAppState.onlineAvailable);
      _breakTargetStartedAt = null;
      _breakTargetMinutes = null;
      SoundService().playStatusOnline();
      ref.invalidate(driverShiftStatsProvider);
      ref.invalidate(driverEarningsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);
    final stats = statsAsync.valueOrNull;
    final isOnline = driver.appState == DriverAppState.onlineAvailable;
    final onBreak = driver.appState == DriverAppState.onBreak;

    if (!isOnline && !onBreak) return const SizedBox.shrink();
    _syncLocalTimerFallback(driver.appState, stats);

    final e = earningsAsync.valueOrNull;
    final todayEuros = e != null ? e.formatEuros(e.todayEuros) : '€0.00';
    final rides = stats?.shiftRidesToday ?? 0;
    final earnings = stats?.shiftEarningsToday ?? 0.0;

    final totalShiftSeconds = _totalShiftSeconds(stats);
    final arcProgress =
        (totalShiftSeconds / (_shiftArcMinutes * 60)).clamp(0.0, 1.0);
    final drivingSeconds = _drivingSecondsLive(stats, onBreak);
    final breakSeconds = _breakSecondsLive(stats, onBreak);
    final primaryClock = onBreak
        ? _formatClock(_currentBreakSeconds(stats))
        : _formatClock(drivingSeconds);
    final breakAssist = _breakAssistModel(
      stats: stats,
      drivingSeconds: drivingSeconds,
      onBreak: onBreak,
    );

    final accent = onBreak ? colors.warning : colors.success;
    final statusLabel = onBreak
        ? DriverStrings.shiftBreakActive
        : DriverStrings.shiftWorkdayActive;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: DriverRadius.lgAll,
          border: Border.all(color: colors.border.withValues(alpha: 0.55)),
          boxShadow: DriverShadows.floating(DriverColors.fromTheme(colors)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DriverSpacing.md,
            DriverSpacing.md,
            DriverSpacing.md,
            DriverSpacing.sm + 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(88, 88),
                          painter: DriverShiftArcPainter(
                            progress: arcProgress,
                            accentColor: accent,
                            trackColor: accent.withValues(alpha: 0.14),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              primaryClock,
                              maxLines: 1,
                              style: typo.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                                fontSize: primaryClock.length > 5 ? 15 : 18,
                              ),
                            ),
                            Text(
                              onBreak
                                  ? DriverStrings.onBreak
                                  : DriverStrings.shiftArcHint,
                              style: typo.labelSmall
                                  .copyWith(color: colors.textSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _PulseDot(color: accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusLabel,
                                style: typo.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DriverStrings.shiftTodaySummary}: $todayEuros · $rides ${DriverStrings.rides}',
                          style: typo.bodySmall.copyWith(color: colors.textMid),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _OutlineBtn(
                                label: onBreak
                                    ? DriverStrings.hervat
                                    : DriverStrings.pauze,
                                colors: colors,
                                typo: typo,
                                busy: _busy,
                                onTap: onBreak
                                    ? _resumeFromBreakOnline
                                    : _chooseAndStartBreak,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _OutlineBtn(
                                label: DriverStrings.stop,
                                colors: colors,
                                typo: typo,
                                busy: _busy,
                                onTap: _onStop,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (breakAssist != null) ...[
                const SizedBox(height: 12),
                _BreakAssistCard(
                  model: breakAssist,
                  colors: colors,
                  typo: typo,
                  accent: accent,
                  busy: _busy,
                  onAction: () {
                    if (onBreak && breakAssist.isComplete) {
                      _resumeFromBreakOnline();
                    } else if (onBreak) {
                      _showBreakLengthSheet().then((minutes) {
                        if (minutes == null || !mounted) return;
                        setState(() {
                          _breakTargetMinutes = minutes;
                          _breakTargetStartedAt = DateTime.now();
                        });
                      });
                    } else {
                      _chooseAndStartBreak();
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: colors.bgAlt.withValues(alpha: 0.65),
                  borderRadius: DriverRadius.mdAll,
                ),
                child: Row(
                  children: [
                    _StatCell(
                      value: _formatCompactDuration(drivingSeconds),
                      label: DriverStrings.shiftStatDriving,
                      typo: typo,
                      colors: colors,
                    ),
                    _VLine(colors: colors),
                    _StatCell(
                      value: _formatCompactDuration(breakSeconds),
                      label: DriverStrings.shiftStatBreak,
                      typo: typo,
                      colors: colors,
                    ),
                    _VLine(colors: colors),
                    _StatCell(
                      value: '$rides',
                      label: DriverStrings.shiftStatRides,
                      typo: typo,
                      colors: colors,
                    ),
                    _VLine(colors: colors),
                    _StatCell(
                      value: '€${earnings.toStringAsFixed(0)}',
                      label: DriverStrings.shiftStatEarnings,
                      typo: typo,
                      colors: colors,
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

  void _syncLocalTimerFallback(DriverAppState state, DriverShiftStats? stats) {
    final stateChanged = _lastObservedState != state;
    _lastObservedState = state;

    if (stateChanged) {
      if (state == DriverAppState.onlineAvailable &&
          stats?.shiftStartAt == null &&
          stats?.continuousDrivingStartedAt == null) {
        _localOnlineStartedAt = DateTime.now();
      }
      if (state == DriverAppState.onBreak && stats?.lastBreakStartAt == null) {
        _localBreakStartedAt = DateTime.now();
      }
      if (state != DriverAppState.onlineAvailable &&
          state != DriverAppState.onBreak) {
        _localOnlineStartedAt = null;
        _localBreakStartedAt = null;
        _breakTargetStartedAt = null;
        _breakTargetMinutes = null;
      }
    }

    if (stats?.shiftStartAt != null ||
        stats?.continuousDrivingStartedAt != null) {
      _localOnlineStartedAt = null;
    }
    if (stats?.lastBreakStartAt != null) {
      _localBreakStartedAt = null;
    }
  }

  int _totalShiftSeconds(DriverShiftStats? stats) {
    final start = stats?.shiftStartAt ?? _localOnlineStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds.clamp(0, 1 << 31);
  }

  int _drivingSecondsLive(DriverShiftStats? stats, bool onBreak) {
    final persistedSeconds = (stats?.shiftTotalOnlineMinutes ?? 0) * 60;
    if (onBreak) return persistedSeconds;
    final start = stats?.continuousDrivingStartedAt ??
        stats?.shiftStartAt ??
        _localOnlineStartedAt;
    if (start == null) return persistedSeconds;
    return DateTime.now().difference(start).inSeconds.clamp(0, 1 << 31);
  }

  int _breakSecondsLive(DriverShiftStats? stats, bool onBreak) {
    var seconds = (stats?.shiftBreakMinutes ?? 0) * 60;
    final start = stats?.lastBreakStartAt ?? _localBreakStartedAt;
    if (onBreak && start != null) {
      seconds += DateTime.now().difference(start).inSeconds.clamp(0, 1 << 31);
    }
    return seconds;
  }

  int _currentBreakSeconds(DriverShiftStats? stats) {
    final start = stats?.lastBreakStartAt ?? _localBreakStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds.clamp(0, 1 << 31);
  }

  String _formatClock(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final h = safeSeconds ~/ 3600;
    final m = (safeSeconds % 3600) ~/ 60;
    final s = safeSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatCompactDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    if (safeSeconds < 60) return '${safeSeconds}s';
    final h = safeSeconds ~/ 3600;
    final m = (safeSeconds % 3600) ~/ 60;
    final s = safeSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  _BreakAssistModel? _breakAssistModel({
    required DriverShiftStats? stats,
    required int drivingSeconds,
    required bool onBreak,
  }) {
    if (onBreak) {
      final minutes = _breakTargetMinutes;
      final startedAt = _breakTargetStartedAt;
      if (minutes == null || startedAt == null) return null;
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      final remaining = (minutes * 60 - elapsed).clamp(0, 1 << 31);
      final complete = remaining == 0;
      return _BreakAssistModel(
        title: complete
            ? DriverStrings.shiftBreakComplete
            : '${DriverStrings.shiftBreakTarget} · ${DriverStrings.shiftBreakMinutes(minutes)}',
        body: complete
            ? DriverStrings.shiftBreakCompleteBody
            : DriverStrings.shiftBreakRemaining(_formatClock(remaining)),
        actionLabel:
            complete ? DriverStrings.goOnline : DriverStrings.shiftChooseBreak,
        isComplete: complete,
      );
    }

    final reminderMinutes = stats?.breakReminderIntervalMinutes ?? 0;
    if (reminderMinutes <= 0) return null;
    final reminderSeconds = reminderMinutes * 60;
    final leadSeconds = (reminderSeconds * 0.2).round().clamp(10 * 60, 30 * 60);
    final shouldRecommend = drivingSeconds >= reminderSeconds - leadSeconds;
    if (!shouldRecommend) return null;

    final overReminder = drivingSeconds >= reminderSeconds;
    final duration = _formatDurationWords(drivingSeconds);
    return _BreakAssistModel(
      title: DriverStrings.shiftBreakReminderTitle,
      body: overReminder
          ? DriverStrings.shiftBreakDueAfter(duration)
          : DriverStrings.shiftBreakConsiderAfter(duration),
      actionLabel: DriverStrings.shiftStartBreak,
      isComplete: false,
    );
  }

  String _formatDurationWords(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final h = safeSeconds ~/ 3600;
    final m = (safeSeconds % 3600) ~/ 60;
    if (h <= 0) return DriverStrings.shiftBreakMinutes(m);
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _BreakAssistModel {
  const _BreakAssistModel({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.isComplete,
  });

  final String title;
  final String body;
  final String actionLabel;
  final bool isComplete;
}

class _BreakAssistCard extends StatelessWidget {
  const _BreakAssistCard({
    required this.model,
    required this.colors,
    required this.typo,
    required this.accent,
    required this.busy,
    required this.onAction,
  });

  final _BreakAssistModel model;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color accent;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              model.isComplete ? Icons.check_rounded : Icons.local_cafe_rounded,
              color: accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  model.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy
                ? null
                : () {
                    HapticService.lightTap();
                    onAction();
                  },
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              model.actionLabel,
              style: typo.labelSmall.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final o = 0.35 + _c.value * 0.45;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: o),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
                blurRadius: 6 + _c.value * 6,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.colors,
    required this.typo,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy
          ? null
          : () {
              HapticService.lightTap();
              onTap();
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style: typo.labelSmall.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.typo,
    required this.colors,
  });

  final String value;
  final String label;
  final HeyCabyTypography typo;
  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: typo.labelLarge
                .copyWith(fontWeight: FontWeight.w800, color: colors.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                typo.labelSmall.copyWith(color: colors.textSoft, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: colors.border.withValues(alpha: 0.6),
    );
  }
}
