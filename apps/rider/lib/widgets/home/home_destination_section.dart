import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/saved_addresses_provider.dart';
import '../../screens/location_required_screen.dart';
import '../../services/booking_flow_navigation.dart';
import '../../services/booking_pickup_from_location.dart';
import '../saved_addresses_sheet.dart';

class HomeDestinationSection extends ConsumerWidget {
  const HomeDestinationSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  Future<void> _continueToSearch(BuildContext context, WidgetRef ref) async {
    final ok = await ensureLocationForBooking(context: context, ref: ref);
    if (!ok) return;
    ref.read(bookingProvider.notifier).setInstant();
    await fillPickupFromCurrentLocation(ref);
    if (context.mounted) context.go('/search');
  }

  Future<void> _openSavedHome(BuildContext context, WidgetRef ref) async {
    final ok = await ensureLocationForBooking(context: context, ref: ref);
    if (!ok || !context.mounted) return;

    final picked = await showSavedAddressesSheet(context, ref);
    if (picked != null && context.mounted) {
      ref.read(bookingProvider.notifier).setDestination(picked);
      await BookingFlowNavigation.prefillBookingFromIdentity(ref);
      if (!context.mounted) return;
      final next = BookingFlowNavigation.routeAfterAddressesComplete(
        ref.read(bookingProvider),
      );
      context.push(next);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSavedHome =
        ref.watch(savedAddressesProvider).valueOrNull?.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
            child: Text(
              l10n.homeDestinationPrompt,
              style: typo.headingMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.2,
              ),
            ),
          ),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _continueToSearch(context, ref),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: colors.textSoft, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.whereTo,
                              style: typo.headingMedium.copyWith(
                                color: colors.textMid,
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSavedHome(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      hasSavedHome ? Icons.home_rounded : Icons.home_outlined,
                      color: hasSavedHome ? colors.accent : colors.textMid,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _continueToSearch(context, ref),
            child: Text(l10n.homeContinue),
          ),
        ],
      ),
    );
  }
}
