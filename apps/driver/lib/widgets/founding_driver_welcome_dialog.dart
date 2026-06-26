import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import 'heycaby_driver_logo.dart';

/// One-time welcome after Edge Function `claim-founding-driver` linked the web signup.
Future<void> showFoundingDriverWelcomeDialog(
  BuildContext parentContext,
  WidgetRef ref,
  ClaimFoundingDriverResult claim,
) async {
  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);

  await showDialog<void>(
    context: parentContext,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: HeyCabyDriverLogo(width: 140),
            ),
            const SizedBox(height: 16),
            Text(
              DriverStrings.foundingDriverWelcomeTitle,
              style: typo.titleLarge.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DriverStrings.foundingDriverWelcomeBody,
                style: typo.bodyMedium.copyWith(color: colors.textMid),
              ),
              if (claim.foundingNumber != null) ...[
                const SizedBox(height: 12),
                Text(
                  DriverStrings.foundingDriverWelcomeNumber(claim.foundingNumber!),
                  style: typo.bodyMedium.copyWith(color: colors.text),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                DriverStrings.foundingDriverWelcomeNext,
                style: typo.bodySmall.copyWith(color: colors.textMid),
              ),
              const SizedBox(height: 20),
              if (claim.needsProfilePhoto) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      ref.read(foundingDriverPostClaimProvider.notifier).state = null;
                      Future.microtask(() {
                        if (parentContext.mounted) parentContext.push('/driver/me');
                      });
                    },
                    child: Text(DriverStrings.foundingDriverProfilePhotoCta),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (claim.needsVehiclePhoto) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      ref.read(foundingDriverPostClaimProvider.notifier).state = null;
                      Future.microtask(() {
                        if (parentContext.mounted) {
                          parentContext.push('/driver/documents');
                        }
                      });
                    },
                    child: Text(DriverStrings.foundingDriverVehiclePhotoCta),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    ref.read(foundingDriverPostClaimProvider.notifier).state = null;
                  },
                  child: Text(DriverStrings.foundingDriverClose),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
