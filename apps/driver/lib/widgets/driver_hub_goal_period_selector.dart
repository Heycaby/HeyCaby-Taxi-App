import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../utils/driver_hub_goal_progress.dart';

/// Premium 4-segment slider for earnings goal period (matches shift toggle feel).
class DriverHubGoalPeriodSelector extends StatefulWidget {
  const DriverHubGoalPeriodSelector({
    super.key,
    required this.period,
    required this.colors,
    required this.typo,
    required this.onPeriodChanged,
  });

  final String period;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<String> onPeriodChanged;

  @override
  State<DriverHubGoalPeriodSelector> createState() =>
      _DriverHubGoalPeriodSelectorState();
}

class _DriverHubGoalPeriodSelectorState extends State<DriverHubGoalPeriodSelector> {
  static const _periods = DriverHubGoalProgress.periods;

  late double _thumbPosition;
  bool _isDragging = false;
  String? _lastDragHapticPeriod;
  bool _didStartDragHaptic = false;

  @override
  void initState() {
    super.initState();
    _thumbPosition = _periodToPosition(widget.period);
  }

  @override
  void didUpdateWidget(covariant DriverHubGoalPeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDragging) return;
    if (oldWidget.period != widget.period) {
      setState(() => _thumbPosition = _periodToPosition(widget.period));
    }
  }

  int _periodToIndex(String period) {
    final idx = _periods.indexOf(period);
    return idx < 0 ? 1 : idx;
  }

  double _periodToPosition(String period) {
    if (_periods.length <= 1) return 0;
    return _periodToIndex(period) / (_periods.length - 1);
  }

  String _positionToPeriod(double position) {
    final idx =
        (position * (_periods.length - 1)).round().clamp(0, _periods.length - 1);
    return _periods[idx];
  }

  void _selectPeriod(String period, {bool haptic = true}) {
    setState(() => _thumbPosition = _periodToPosition(period));
    if (period == widget.period) {
      if (haptic) HapticService.selectionClick();
      return;
    }
    if (haptic) HapticService.mediumTap();
    widget.onPeriodChanged(period);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final activePeriod =
        _isDragging ? _positionToPeriod(_thumbPosition) : widget.period;
    final activeTint = colors.accent;
    final labelStyle = typo.labelSmall.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const trackHeight = 54.0;
        final segmentWidth = width / _periods.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DriverStrings.hubSetGoalForPeriod,
              style: typo.labelLarge.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTapUp: (details) {
                final dx = details.localPosition.dx.clamp(0.0, width);
                final index =
                    (dx / segmentWidth).floor().clamp(0, _periods.length - 1);
                _selectPeriod(_periods[index]);
              },
              onHorizontalDragStart: (_) {
                setState(() => _isDragging = true);
                if (!_didStartDragHaptic) {
                  HapticService.selectionClick();
                  _didStartDragHaptic = true;
                }
                _lastDragHapticPeriod = _positionToPeriod(_thumbPosition);
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final delta = details.delta.dx / (width - segmentWidth);
                  _thumbPosition = (_thumbPosition + delta).clamp(0.0, 1.0);
                });
                final newPeriod = _positionToPeriod(_thumbPosition);
                if (newPeriod != _lastDragHapticPeriod) {
                  _lastDragHapticPeriod = newPeriod;
                  HapticService.selectionClick();
                }
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
                _didStartDragHaptic = false;
                final snapped = _positionToPeriod(_thumbPosition);
                _selectPeriod(snapped, haptic: false);
                HapticService.mediumTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: trackHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.surface.withValues(alpha: 0.96),
                      Color.alphaBlend(
                        activeTint.withValues(alpha: 0.08),
                        colors.card,
                      ),
                      colors.card.withValues(alpha: 0.98),
                    ],
                    stops: const [0, 0.54, 1],
                  ),
                  border: Border.all(
                    color: activeTint.withValues(alpha: 0.22),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeTint.withValues(alpha: 0.12),
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
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          -1 + 2 * _thumbPosition,
                          0,
                        ),
                        child: Container(
                          width: segmentWidth,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.card,
                                Color.alphaBlend(
                                  activeTint.withValues(alpha: 0.14),
                                  colors.card,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: activeTint.withValues(alpha: 0.42),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeTint.withValues(alpha: 0.22),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < _periods.length; i++)
                          Expanded(
                            child: _GoalPeriodSegmentLabel(
                              label: DriverHubGoalProgress.periodShortLabel(
                                _periods[i],
                              ),
                              active: activePeriod == _periods[i],
                              activeColor: activeTint,
                              inactiveColor: colors.textMid,
                              style: labelStyle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                DriverHubGoalProgress.periodLabel(activePeriod),
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GoalPeriodSegmentLabel extends StatelessWidget {
  const _GoalPeriodSegmentLabel({
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
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        style: style.copyWith(
          color: active ? activeColor : inactiveColor,
          fontSize: active ? 11.5 : 10.5,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
