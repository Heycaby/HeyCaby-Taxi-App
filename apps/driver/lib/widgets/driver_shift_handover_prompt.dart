import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_shift_handover_prompt_args.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../utils/driver_shift_handover_confirm.dart';
import '../utils/driver_taxi_session_revoked_flow.dart';

/// High-priority modal for the active driver when another driver requests shift handover.
Future<void> showDriverShiftHandoverPrompt({
  required BuildContext context,
  required WidgetRef ref,
  required DriverShiftHandoverPromptArgs args,
}) async {
  if (!context.mounted) return;
  await HapticService.heavyTap();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _DriverShiftHandoverPromptSheet(args: args);
    },
  );
}

class _DriverShiftHandoverPromptSheet extends ConsumerStatefulWidget {
  const _DriverShiftHandoverPromptSheet({required this.args});

  final DriverShiftHandoverPromptArgs args;

  @override
  ConsumerState<_DriverShiftHandoverPromptSheet> createState() =>
      _DriverShiftHandoverPromptSheetState();
}

class _DriverShiftHandoverPromptSheetState
    extends ConsumerState<_DriverShiftHandoverPromptSheet> {
  bool _busy = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final expires = widget.args.expiresAt;
    if (expires == null || !mounted) return;
    setState(() {
      _remaining = expires.difference(DateTime.now().toUtc());
    });
  }

  String _formatRemaining() {
    final total = _remaining.inSeconds.clamp(0, 9999);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _graceMinutes {
    final secs = widget.args.graceSeconds;
    if (secs != null && secs > 0) return (secs / 60).ceil();
    return 2;
  }

  Future<void> _respond(String action) async {
    if (_busy) return;
    if (action == 'approve') {
      final confirmed = await confirmShiftHandoverHighRiskAction(context);
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy = true);
    final res = await ref.read(driverDataServiceProvider).respondShiftHandover(
          requestId: widget.args.requestId,
          action: action,
        );
    if (!mounted) return;
    Navigator.of(context).pop();

    if (action == 'approve' && res?['ok'] == true && mounted) {
      await handleDriverTaxiSessionRevoked(
        context: context,
        ref: ref,
        plate: widget.args.plateDisplay,
        voluntaryEnd: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final args = widget.args;
    final plate = args.plateDisplay ?? '';
    final photoUrl = args.profilePhotoUrl?.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.screenEdge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DriverSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.shiftHandoverPromptTitle,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colors.background,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(LucideIcons.user, color: colors.textSecondary)
                          : null,
                    ),
                    const SizedBox(width: DriverSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.shiftHandoverPromptLead(
                              args.displayName,
                              plate,
                            ),
                            style: typography.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: DriverSpacing.xs),
                          Text(
                            args.starsLabel,
                            style: typography.bodyMedium.copyWith(
                              color: colors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (args.memberSinceYear != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              DriverStrings.shiftHandoverPromptMemberSince(
                                args.memberSinceYear!,
                              ),
                              style: typography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (args.verified) ...[
                            const SizedBox(height: DriverSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.badgeCheck,
                                  size: 16,
                                  color: colors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DriverStrings.shiftHandoverPromptVerified,
                                  style: typography.labelSmall.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (args.expiresAt != null) ...[
                  const SizedBox(height: DriverSpacing.lg),
                  Text(
                    _formatRemaining(),
                    textAlign: TextAlign.center,
                    style: typography.headlineSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: DriverSpacing.md),
                Text(
                  DriverStrings.shiftHandoverPromptTimeoutHint(_graceMinutes),
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  DriverStrings.shiftHandoverPromptUnexpected,
                  style: typography.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: DriverSpacing.xl),
                DriverButton(
                  label: DriverStrings.shiftHandoverEndShift,
                  onPressed: _busy ? null : () => _respond('approve'),
                  loading: _busy,
                  colors: colors,
                  typography: typography,
                  size: DriverButtonSize.lg,
                  icon: LucideIcons.logOut,
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverButton(
                  label: DriverStrings.shiftHandoverStillDriving,
                  onPressed: _busy ? null : () => _respond('deny'),
                  variant: DriverButtonVariant.outline,
                  colors: colors,
                  typography: typography,
                  size: DriverButtonSize.lg,
                  icon: LucideIcons.shieldAlert,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
