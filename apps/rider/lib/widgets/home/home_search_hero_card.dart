import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/saved_addresses_provider.dart';
import '../../screens/location_required_screen.dart';
import '../../services/booking_saved_place_shortcut.dart';
import '../../services/booking_pickup_from_location.dart';
import '../saved_addresses_add_sheet.dart';

SavedAddress? _savedHome(List<SavedAddress> saved) {
  for (final address in saved) {
    if (address.type == 'home') return address;
  }
  return null;
}

/// Hero search card
class HomeSearchHeroCard extends ConsumerWidget {
  const HomeSearchHeroCard({
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

  Future<void> _openHomeShortcut(BuildContext context, WidgetRef ref) async {
    await ref.read(savedAddressesProvider.notifier).refresh();
    if (!context.mounted) return;

    var home = _savedHome(ref.read(savedAddressesProvider).valueOrNull ?? []);

    if (home == null) {
      final colors = ref.read(colorsProvider);
      final typo = ref.read(typographyProvider);
      final sheetL10n = AppLocalizations.of(context);
      final added = await showAddSavedAddressSheet(
        context,
        colors: colors,
        typo: typo,
        l10n: sheetL10n,
        initialType: 'home',
      );
      if (!context.mounted || added != true) return;
      await ref.read(savedAddressesProvider.notifier).refresh();
      home = _savedHome(ref.read(savedAddressesProvider).valueOrNull ?? []);
      if (home == null) return;
    }

    if (!context.mounted) return;
    await bookInstantRideToDestination(
      context,
      ref,
      addressResultFromSaved(home),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasHome = (ref.watch(savedAddressesProvider).valueOrNull ?? [])
        .any((a) => a.type == 'home');

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.whereAreYouGoing,
              style: typo.headingMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: colors.bgAlt,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _continueToSearch(context, ref),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: colors.accent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.homeEnterDestination,
                                style: typo.bodyLarge.copyWith(
                                  color: colors.textMid,
                                  fontWeight: FontWeight.w500,
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
                ),
                const SizedBox(width: 10),
                _HomeShortcutButton(
                  colors: colors,
                  typo: typo,
                  label: l10n.savedAddressLabelHome,
                  highlighted: hasHome,
                  onTap: () => _openHomeShortcut(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeShortcutButton extends StatelessWidget {
  const _HomeShortcutButton({
    required this.colors,
    required this.typo,
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.bgAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  highlighted ? Icons.home_rounded : Icons.home_outlined,
                  color: highlighted ? colors.accent : colors.textMid,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
