import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';

bool _taxiSessionRevokeHandled = false;

bool markTaxiSessionRevokeHandled() {
  if (_taxiSessionRevokeHandled) return false;
  _taxiSessionRevokeHandled = true;
  return true;
}

void resetTaxiSessionRevokeHandled() {
  _taxiSessionRevokeHandled = false;
}

/// Force offline when taxi session ownership changes (handover approve/timeout).
Future<void> handleDriverTaxiSessionRevoked({
  required BuildContext context,
  required WidgetRef ref,
  String? plate,
  String? reason,
  bool voluntaryEnd = false,
}) async {
  if (!context.mounted) return;
  if (!markTaxiSessionRevokeHandled()) return;

  await HapticService.heavyTap();
  await DriverLocationService().syncWithAppState(DriverAppState.offline);
  ref.read(driverStateProvider.notifier).setStatus(DriverAppState.offline);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverComplianceProvider);
  unawaited(SoundService().playStatusOffline());

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final colors = DriverColors.fromTheme(ref.read(colorsProvider));
      final typo = DriverTypography.fromTheme(ref.read(typographyProvider));
      final title = voluntaryEnd
          ? DriverStrings.taxiSessionRevokedVoluntaryTitle
          : DriverStrings.taxiSessionRevokedTitle;
      final body = voluntaryEnd
          ? DriverStrings.taxiSessionRevokedVoluntaryBody(plate ?? '')
          : DriverStrings.taxiSessionRevokedBody(plate ?? '');
      return AlertDialog(
        icon: Icon(Icons.local_taxi_rounded, color: colors.warning, size: 40),
        title: Text(
          title,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          body,
          style: typo.bodyMedium
              .copyWith(color: colors.textSecondary, height: 1.35),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(DriverStrings.taxiSessionRevokedCta),
            ),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;
  context.go('/driver');
}
