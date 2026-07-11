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

/// Minimal iOS-style schedule sheet — single date+time wheel, no overflow.
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

  void _coerceSelection() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = _clampToScheduleGrid(_selected);

    var dayStart = DateTime(candidate.year, candidate.month, candidate.day);
    if (dayStart.isBefore(_minDate)) {
      dayStart = _minDate;
      candidate = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        candidate.hour,
        candidate.minute,
      );
    }
    if (dayStart.isAfter(_maxDate)) {
      dayStart = _maxDate;
      candidate = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        candidate.hour,
        candidate.minute,
      );
    }

    if (_sameCalendarDay(dayStart, today)) {
      final minAllowed = _clampToScheduleGrid(now.add(const Duration(minutes: 1)));
      if (candidate.isBefore(minAllowed)) {
        if (_sameCalendarDay(minAllowed, today)) {
          candidate = DateTime(
            today.year,
            today.month,
            today.day,
            minAllowed.hour,
            minAllowed.minute,
          );
        } else {
          candidate = minAllowed;
        }
      }
    }

    _selected = _clampToScheduleGrid(candidate);
  }

  void _onDateTimeChanged(DateTime picked) {
    setState(() {
      _selected = picked;
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
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
      ),
    );

    final pickerSeed = _selected.isBefore(_minDate)
        ? _minDate
        : (_selected.isAfter(_maxDate) ? _maxDate : _selected);

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scheduleYourRide,
                          style: typo.titleLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _summaryLine(context),
                          style: typo.bodyMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(Icons.close_rounded, color: colors.textSoft),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: cupertino,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: true,
                  minuteInterval: 15,
                  initialDateTime: pickerSeed,
                  minimumDate: _minDate,
                  maximumDate: _maxDate.add(
                    const Duration(hours: 23, minutes: 45),
                  ),
                  onDateTimeChanged: _onDateTimeChanged,
                ),
              ),
            ),
            Divider(height: 1, color: colors.border.withValues(alpha: 0.65)),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.saveTripForNextTimeLabel,
                      style: typo.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _saveTripForNextTime,
                    onChanged: (v) => setState(() => _saveTripForNextTime = v),
                    activeTrackColor: colors.accent,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.confirmSchedule,
                    style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
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
  return showModalBottomSheet<SchedulePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SchedulePickerModal(
          initialDate: initialDate,
          onConfirm: (result) => Navigator.pop(context, result),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    ),
  );
}
