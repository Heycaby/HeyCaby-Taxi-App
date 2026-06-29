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

  Future<void> _onStop() async {
    final stats = ref.read(driverShiftStatsProvider).valueOrNull;
    final onlineMins = stats?.shiftTotalOnlineMinutes ?? 0;
    final rides = stats?.shiftRidesToday ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ref.read(colorsProvider);
        final typo = ref.read(typographyProvider);
        return AlertDialog(
          title: Text(DriverStrings.endShiftConfirm, style: typo.titleMedium),
          content: Text(
            DriverStrings.endShiftDetail
                .replaceFirst(
                    'X hours', '${onlineMins ~/ 60}h ${onlineMins % 60}m')
                .replaceFirst('Y rides', '$rides rides'),
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(DriverStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.card,
              ),
              child: const Text(DriverStrings.endShift),
            ),
          ],
        );
      },
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

    final e = earningsAsync.valueOrNull;
    final todayEuros = e != null ? e.formatEuros(e.todayEuros) : '€0.00';
    final rides = stats?.shiftRidesToday ?? 0;
    final earnings = stats?.shiftEarningsToday ?? 0.0;

    final totalShiftMin = _totalShiftMinutes(stats);
    final arcProgress = (totalShiftMin / _shiftArcMinutes).clamp(0.0, 1.0);
    final drivingMin = _drivingMinutesLive(stats, onBreak);
    final breakMin = _breakMinutesLive(stats, onBreak);

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
                              onBreak
                                  ? _formatHm(_currentBreakMinutes(stats))
                                  : _formatHm(drivingMin),
                              style: typo.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                                fontSize: 18,
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
                                    : () => _setStatus(
                                        'on_break', DriverAppState.onBreak),
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
                      value: '${drivingMin}m',
                      label: DriverStrings.shiftStatDriving,
                      typo: typo,
                      colors: colors,
                    ),
                    _VLine(colors: colors),
                    _StatCell(
                      value: '${breakMin}m',
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

  int _totalShiftMinutes(DriverShiftStats? stats) {
    final start = stats?.shiftStartAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMinutes;
  }

  int _drivingMinutesLive(DriverShiftStats? stats, bool onBreak) {
    if (stats == null) return 0;
    if (onBreak) return stats.shiftTotalOnlineMinutes;
    final start = stats.continuousDrivingStartedAt ?? stats.shiftStartAt;
    if (start == null) return stats.shiftTotalOnlineMinutes;
    return DateTime.now().difference(start).inMinutes;
  }

  int _breakMinutesLive(DriverShiftStats? stats, bool onBreak) {
    if (stats == null) return 0;
    var b = stats.shiftBreakMinutes;
    if (onBreak && stats.lastBreakStartAt != null) {
      b += DateTime.now().difference(stats.lastBreakStartAt!).inMinutes;
    }
    return b;
  }

  int _currentBreakMinutes(DriverShiftStats? stats) {
    if (stats?.lastBreakStartAt == null) return 0;
    return DateTime.now().difference(stats!.lastBreakStartAt!).inMinutes;
  }

  String _formatHm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
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
