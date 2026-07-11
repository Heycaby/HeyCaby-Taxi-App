import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../services/booking_saved_place_shortcut.dart';
import '../widgets/booking/booking_flow_screen_header.dart';
import '../providers/saved_addresses_provider.dart';
import '../widgets/saved_addresses_add_sheet.dart';
import '../widgets/saved_places_premium_widgets.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final identityAsync = ref.watch(riderIdentityProvider);
    final addressesAsync = ref.watch(savedAddressesProvider);

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Padding(
        padding: EdgeInsets.only(top: topInset + 12, bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.savedAddresses,
              subtitle: l10n.savedAddressesSubtitle,
              icon: Icons.bookmark_rounded,
              onBack: () => Navigator.of(context).pop(),
              trailing: identityAsync.whenData((identity) {
                if (!identity.hasSession) return const SizedBox.shrink();
                return IconButton(
                  onPressed: () => _showAdd(context, colors, typo, l10n),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.accentL,
                    foregroundColor: colors.accent,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                );
              }).valueOrNull,
            ),
            Expanded(
              child: addressesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(l10n.error, style: typo.bodyMedium),
                ),
                data: (addresses) {
                  if (addresses.isEmpty) {
                    final hasSession = ref
                            .read(riderIdentityProvider)
                            .valueOrNull
                            ?.hasSession ??
                        false;
                    if (!hasSession) {
                      return const SizedBox.shrink();
                    }
                    return SavedPlacesEmptyState(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      onAdd: () => _showAdd(
                        context,
                        colors,
                        typo,
                        l10n,
                      ),
                      onShortcut: (type) => _showAdd(
                        context,
                        colors,
                        typo,
                        l10n,
                        initialType: type,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.all(16),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      return SavedPlacesAddressTile(
                        address: addr,
                        colors: colors,
                        typo: typo,
                        editLabel: l10n.editSavedAddress,
                        deleteLabel: l10n.deleteSavedAddress,
                        onBook: () {
                          bookInstantRideToDestination(
                            context,
                            ref,
                            addressResultFromSaved(addr),
                          );
                        },
                        onEdit: () => _showEdit(
                          context,
                          colors,
                          typo,
                          l10n,
                          addr,
                        ),
                        onDelete: () => ref
                            .read(savedAddressesProvider.notifier)
                            .remove(addr.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdd(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n, {
    String initialType = 'home',
  }) async {
    await showAddSavedAddressSheet(
      context,
      colors: colors,
      typo: typo,
      l10n: l10n,
      initialType: initialType,
    );
  }

  Future<void> _showEdit(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
    SavedAddress address,
  ) async {
    await showEditSavedAddressSheet(
      context,
      colors: colors,
      typo: typo,
      l10n: l10n,
      address: address,
    );
  }
}
