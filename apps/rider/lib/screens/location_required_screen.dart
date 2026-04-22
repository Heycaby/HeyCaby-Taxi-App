import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/location_provider.dart';
import '../services/location_service.dart';

/// Full-screen blocker when location is denied. No booking possible until enabled.
class LocationRequiredScreen extends ConsumerWidget {
  const LocationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 72,
                color: colors.textSoft,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.locationRequired,
                style: typo.headingLarge.copyWith(color: colors.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.locationRequiredMessage,
                style: typo.bodyMedium.copyWith(color: colors.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: Text(
                    l10n.enableLocation,
                    style: typo.labelLarge.copyWith(color: colors.onAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final pos = await LocationService.requestAndGetLocation();
                  if (pos != null && context.mounted) {
                    ref.read(locationProvider.notifier).setPosition(pos);
                    if (context.mounted) context.go('/home');
                  }
                },
                child: Text(
                  l10n.tryAgain,
                  style: typo.bodyMedium.copyWith(color: colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
