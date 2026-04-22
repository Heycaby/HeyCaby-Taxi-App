import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/booking_provider.dart';
import '../providers/settings_provider.dart';

const kWelcomeProfileFlowCompletedKey = 'rider_welcome_profile_flow_done';

Future<bool> isWelcomeProfileFlowCompleted() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(kWelcomeProfileFlowCompletedKey) ?? false;
}

Future<void> markWelcomeProfileFlowCompleted() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(kWelcomeProfileFlowCompletedKey, true);
}

enum _WelcomeIntroResult { setUpNow, later }

/// First-time welcome on home: profile recommendation, then optional driver name.
Future<void> maybePresentWelcomeProfileFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (!context.mounted) return;
  if (await isWelcomeProfileFlowCompleted()) return;

  await ref.read(settingsProvider.future);
  await ref.read(riderIdentityProvider.future);
  if (!context.mounted) return;

  final settings = ref.read(settingsProvider).valueOrNull;
  if ((settings?.userName ?? '').trim().isNotEmpty) {
    await markWelcomeProfileFlowCompleted();
    return;
  }
  final identity = ref.read(riderIdentityProvider).valueOrNull;
  if ((identity?.bookingName ?? '').trim().isNotEmpty) {
    await markWelcomeProfileFlowCompleted();
    return;
  }

  if (!context.mounted) return;

  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final l10n = AppLocalizations.of(context);

  final introResult = await showDialog<_WelcomeIntroResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n.welcomeProfileModalTitle,
        style: typo.headingMedium.copyWith(color: colors.text),
      ),
      content: SingleChildScrollView(
        child: Text(
          l10n.welcomeProfileModalBody,
          style: typo.bodyLarge.copyWith(color: colors.textMid, height: 1.5),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _WelcomeIntroResult.later),
          child: Text(l10n.laterButton),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _WelcomeIntroResult.setUpNow),
          child: Text(l10n.setUpProfileNow),
        ),
      ],
    ),
  );

  if (!context.mounted) return;

  if (introResult == _WelcomeIntroResult.setUpNow) {
    await markWelcomeProfileFlowCompleted();
    if (!context.mounted) return;
    context.push('/account?fromOnboarding=true');
    return;
  }

  if (introResult == _WelcomeIntroResult.later) {
    await _showDriverCallNameDialog(context, ref, colors, typo, l10n);
  }
}

Future<void> _showDriverCallNameDialog(
  BuildContext context,
  WidgetRef ref,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
  AppLocalizations l10n,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DriverCallNameDialog(
      ref: ref,
      colors: colors,
      typo: typo,
      l10n: l10n,
    ),
  );
}

class _DriverCallNameDialog extends StatefulWidget {
  const _DriverCallNameDialog({
    required this.ref,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final WidgetRef ref;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  State<_DriverCallNameDialog> createState() => _DriverCallNameDialogState();
}

class _DriverCallNameDialogState extends State<_DriverCallNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.l10n.welcomeDriverCallYouModalTitle,
        style: widget.typo.headingMedium.copyWith(color: widget.colors.text),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: widget.l10n.namePlaceholder,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () async {
            await markWelcomeProfileFlowCompleted();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(widget.l10n.welcomeSkipDriverName),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () async {
                  final name = _controller.text.trim();
                  await widget.ref.read(settingsProvider.notifier).setUserName(name);
                  await widget.ref
                      .read(riderIdentityProvider.notifier)
                      .saveBookingName(name);
                  widget.ref
                      .read(bookingProvider.notifier)
                      .setPickupContactName(name);
                  await markWelcomeProfileFlowCompleted();
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: Text(widget.l10n.saveButton),
        ),
      ],
    );
  }
}
