import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/location_provider.dart';
import '../services/location_service.dart';

/// Booking-time location guard.
///
/// Flow:
/// - If already permitted, returns true immediately.
/// - If denied, shows a pull-up sheet that can be dismissed (X / swipe down).
/// - Returns true only after location is granted and resolved.
Future<bool> ensureLocationForBooking({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final pos = await LocationService.requestAndGetLocation();
  if (pos != null) {
    ref.read(locationProvider.notifier).setPosition(pos);
    return true;
  }
  if (!context.mounted) return false;
  final granted = await showLocationRequiredSheet(context: context, ref: ref);
  return granted ?? false;
}

Future<bool?> showLocationRequiredSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LocationRequiredBottomSheet(ref: ref),
  );
}

/// Full-screen variant kept for backwards compatibility with route usage.
class LocationRequiredScreen extends ConsumerWidget {
  const LocationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LocationRequiredFullScreen(ref: ref);
  }
}

class _LocationRequiredBottomSheet extends ConsumerWidget {
  const _LocationRequiredBottomSheet({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded, color: colors.textMid),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.location_off_outlined,
                  size: 54,
                  color: colors.textSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.locationRequired,
                  style: typo.headingLarge.copyWith(color: colors.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.locationRequiredMessage,
                  style: typo.bodyMedium.copyWith(color: colors.textMid),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final pos = await LocationService.requestAndGetLocation();
                    if (pos != null && context.mounted) {
                      ref.read(locationProvider.notifier).setPosition(pos);
                      Navigator.of(context).pop(true);
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
      ),
    );
  }
}

class _LocationRequiredFullScreen extends ConsumerWidget {
  const _LocationRequiredFullScreen({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
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
