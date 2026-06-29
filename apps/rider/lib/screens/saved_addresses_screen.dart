import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../providers/saved_addresses_provider.dart';
import '../widgets/saved_addresses_add_sheet.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final identityAsync = ref.watch(riderIdentityProvider);
    final addressesAsync = ref.watch(savedAddressesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
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
                if (identity.identityId == null) return const SizedBox.shrink();
                return IconButton(
                  onPressed: () =>
                      _showAdd(context, identity.identityId!, colors, typo, l10n),
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
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.accent.withValues(alpha: 0.2),
                            colors.accent.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: colors.accent,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.noSavedAddressesYet,
                      textAlign: TextAlign.center,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.noSavedAddressesEmptyBody,
                      textAlign: TextAlign.center,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textSoft,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {
                          final identityId = ref
                              .read(riderIdentityProvider)
                              .valueOrNull
                              ?.identityId;
                          if (identityId == null) return;
                          _showAdd(context, identityId, colors, typo, l10n);
                        },
                        icon: Icon(Icons.add_rounded, color: colors.onAccent),
                        label: Text(
                          l10n.addSavedAddress,
                          style: typo.labelLarge.copyWith(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsetsDirectional.all(16),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return _AddressTile(
                address: addr,
                colors: colors,
                typo: typo,
                onDelete: () =>
                    ref.read(savedAddressesProvider.notifier).remove(addr.id),
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

  void _showAdd(
    BuildContext context,
    String identityId,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
  ) {
    showAddSavedAddressSheet(
      context,
      identityId: identityId,
      colors: colors,
      typo: typo,
      l10n: l10n,
    );
  }
}

class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.colors,
    required this.typo,
    required this.onDelete,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'work': return Icons.work_outline_rounded;
      case 'gym': return Icons.fitness_center_rounded;
      case 'home': return Icons.home_rounded;
      default: return Icons.star_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.accentL,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForType(address.type), color: colors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.label,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address.fullAddress,
                  style: typo.bodySmall.copyWith(color: colors.textSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: colors.textSoft, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
