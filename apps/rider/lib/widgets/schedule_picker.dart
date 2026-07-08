import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

class SchedulePickerResult {
  final DateTime dateTime;
  final bool saveTrip;

  const SchedulePickerResult(this.dateTime, {this.saveTrip = false});
}

/// Sleek date + time scheduling using inline Cupertino wheels (alarm / iOS-style),
/// themed with HeyCaby tokens — not a dense time-chip grid.
class SchedulePickerModal extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final void Function(SchedulePickerResult) onConfirm;
  final VoidCallback onCancel;

  const SchedulePickerModal({
    super.key,
    this.initialDate,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  ConsumerState<SchedulePickerModal> createState() => _SchedulePickerModalState();
}

class _SchedulePickerModalState extends ConsumerState<SchedulePickerModal> {
  late DateTime _selected;
  late DateTime _minDate;
  late DateTime _maxDate;
  bool _saveTripForNextTime = false;

  static const _pickerH = 172.0;
  static const _maxDaysAhead = 30;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minDate = DateTime(now.year, now.month, now.day);
    _maxDate = _minDate.add(const Duration(days: _maxDaysAhead));

    var seed = widget.initialDate ?? now.add(const Duration(hours: 1));
    seed = _clampToScheduleGrid(seed);
    if (seed.isBefore(_minDate)) {
      seed = _clampToScheduleGrid(_minDate.add(const Duration(hours: 1)));
    }
    if (seed.isAfter(_maxDate.add(const Duration(hours: 23, minutes: 45)))) {
      seed = DateTime(_maxDate.year, _maxDate.month, _maxDate.day, 18, 0);
    }
    _selected = seed;
    _coerceSelection();
  }

  DateTime _clampToScheduleGrid(DateTime d) {
    var base = DateTime(d.year, d.month, d.day, d.hour, d.minute);
    var minute = (base.minute / 15).round() * 15;
    var hour = base.hour;
    if (minute >= 60) {
      hour += 1;
      minute = 0;
    }
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Keeps selection on 15-minute steps, within [ _minDate, _maxDate ], and not in the past for today.
  void _coerceSelection() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = _clampToScheduleGrid(_selected);

    var dayStart = DateTime(candidate.year, candidate.month, candidate.day);
    if (dayStart.isBefore(_minDate)) {
      dayStart = _minDate;
      candidate = DateTime(dayStart.year, dayStart.month, dayStart.day, candidate.hour, candidate.minute);
    }
    if (dayStart.isAfter(_maxDate)) {
      dayStart = _maxDate;
      candidate = DateTime(dayStart.year, dayStart.month, dayStart.day, candidate.hour, candidate.minute);
    }

    if (_sameCalendarDay(dayStart, today)) {
      final minAllowed = _clampToScheduleGrid(now.add(const Duration(minutes: 1)));
      if (candidate.isBefore(minAllowed)) {
        if (_sameCalendarDay(minAllowed, today)) {
          candidate = DateTime(today.year, today.month, today.day, minAllowed.hour, minAllowed.minute);
        } else {
          candidate = minAllowed;
        }
      }
    }

    _selected = _clampToScheduleGrid(candidate);
  }

  void _onDateChanged(DateTime picked) {
    setState(() {
      _selected = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selected.hour,
        _selected.minute,
      );
      _selected = _clampToScheduleGrid(_selected);
      _coerceSelection();
    });
  }

  void _onTimeChanged(DateTime picked) {
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        picked.hour,
        picked.minute,
      );
      _selected = _clampToScheduleGrid(_selected);
      _coerceSelection();
    });
  }

  String _summaryLine(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final datePart = DateFormat.yMMMEd(locale).format(_selected);
    final timePart = DateFormat.Hm(locale).format(_selected);
    return '$datePart · $timePart';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final cupertino = CupertinoThemeData(
      brightness: brightness,
      primaryColor: colors.accent,
      textTheme: CupertinoTextThemeData(
        dateTimePickerTextStyle: typo.titleMedium.copyWith(
          color: colors.text,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.scheduleYourRide,
                      style: typo.headingMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(Icons.close_rounded, color: colors.textMid),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: colors.accent, size: 22),
                    const SizedBox(width: 10),
                    Icon(Icons.schedule_rounded, color: colors.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _summaryLine(context),
                        style: typo.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.selectDate,
                  style: typo.labelLarge.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _pickerH,
              child: CupertinoTheme(
                data: cupertino,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selected.isBefore(_minDate)
                      ? _minDate
                      : (_selected.isAfter(_maxDate) ? _maxDate : _selected),
                  minimumDate: _minDate,
                  maximumDate: _maxDate,
                  onDateTimeChanged: _onDateChanged,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.selectTime,
                  style: typo.labelLarge.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _pickerH,
              child: CupertinoTheme(
                data: cupertino,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 15,
                  initialDateTime: _selected,
                  onDateTimeChanged: _onTimeChanged,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.saveTripForNextTimeLabel,
                            style: typo.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.saveTripForNextTimeSubtitle,
                            style: typo.bodySmall.copyWith(
                              color: colors.textMid,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _saveTripForNextTime,
                      onChanged: (v) =>
                          setState(() => _saveTripForNextTime = v),
                      activeTrackColor: colors.accent,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    _coerceSelection();
                    widget.onConfirm(
                      SchedulePickerResult(
                        _selected,
                        saveTrip: _saveTripForNextTime,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.confirmSchedule,
                    style: typo.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<SchedulePickerResult?> showSchedulePicker(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final h = MediaQuery.sizeOf(context).height * 0.82;
  return showModalBottomSheet<SchedulePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SizedBox(
      height: h,
      child: SchedulePickerModal(
        initialDate: initialDate,
        onConfirm: (result) => Navigator.pop(context, result),
        onCancel: () => Navigator.pop(context),
      ),
    ),
  );
}
