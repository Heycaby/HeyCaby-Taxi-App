import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_text_field.dart';

/// Compact bottom sheet to save the accountant email for finance exports.
Future<String?> showDriverAccountantEmailSheet({
  required BuildContext context,
  required DriverColors colors,
  required DriverTypography typography,
  String? initialEmail,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.34),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _DriverAccountantEmailSheet(
        colors: colors,
        typography: typography,
        initialEmail: initialEmail,
      ),
    ),
  );
}

class _DriverAccountantEmailSheet extends StatefulWidget {
  const _DriverAccountantEmailSheet({
    required this.colors,
    required this.typography,
    this.initialEmail,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String? initialEmail;

  @override
  State<_DriverAccountantEmailSheet> createState() =>
      _DriverAccountantEmailSheetState();
}

class _DriverAccountantEmailSheetState extends State<_DriverAccountantEmailSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) return true;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  void _save() {
    final value = _controller.text.trim();
    if (!_isValidEmail(value)) {
      setState(() => _errorText = DriverStrings.financeAccountantDialogInvalid);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.sheetTop,
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.sm,
          DriverSpacing.screenEdge,
          DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.financeAccountantDialogTitle,
                    style: typography.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    HapticService.selectionClick();
                    Navigator.pop(context);
                  },
                  tooltip: DriverStrings.close,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.xs),
            Text(
              DriverStrings.financeAccountantSheetHint,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DriverSpacing.md),
            DriverTextField(
              controller: _controller,
              colors: colors,
              typography: typography,
              hint: DriverStrings.financeAccountantDialogHint,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              errorText: _errorText,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: DriverSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(DriverStrings.financeAccountantDialogCancel),
                  ),
                ),
                const SizedBox(width: DriverSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticService.mediumTap();
                      _save();
                    },
                    child: Text(DriverStrings.financeAccountantDialogSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
