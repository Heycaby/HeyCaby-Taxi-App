import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/saved_addresses_provider.dart';
import 'email_modal.dart';
import 'saved_addresses_add_sheet.dart';

/// Shows the saved addresses sheet. Returns an [AddressResult] when the
/// rider taps one, null otherwise.
Future<AddressResult?> showSavedAddressesSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(savedAddressesProvider.notifier).refresh();
  if (!context.mounted) return null;
  return showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final h = (media.size.height * 0.88)
          .clamp(0.0, media.size.height - media.padding.top - 8.0);
      return SizedBox(
        height: h,
        child: const _SavedAddressesSheet(),
      );
    },
  );
}

class _SavedAddressesSheet extends ConsumerStatefulWidget {
  const _SavedAddressesSheet();

  @override
  ConsumerState<_SavedAddressesSheet> createState() =>
      _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends ConsumerState<_SavedAddressesSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(savedAddressesProvider.notifier).refresh();
    });
  }

  void _openAdd(String identityId, HeyCabyColorTokens colors,
      HeyCabyTypography typo, AppLocalizations l10n) {
    showAddSavedAddressSheet(
      context,
      identityId: identityId,
      colors: colors,
      typo: typo,
      l10n: l10n,
      initialType: 'home',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final identityAsync = ref.watch(riderIdentityProvider);
    final addressesAsync = ref.watch(savedAddressesProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.accent.withValues(alpha: 0.1),
                    colors.surface,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: true,
            child: Column(
              children: [
                _DragHandle(colors: colors),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.accentL,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            Icon(Icons.home_rounded, color: colors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.savedAddresses,
                              style: typo.headingMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.savedPlacesSheetSubtitle,
                              style: typo.bodySmall.copyWith(
                                color: colors.textSoft,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: colors.textMid),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: identityAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (identity) {
                      if (!identity.hasSession || identity.identityId == null) {
                        return SingleChildScrollView(
                          padding:
                              const EdgeInsetsDirectional.only(bottom: 16),
                          child: _NoIdentityState(
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          ),
                        );
                      }

                      return addressesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (addresses) {
                          if (addresses.isEmpty) {
                            return SingleChildScrollView(
                              padding:
                                  const EdgeInsetsDirectional.only(bottom: 16),
                              child: _EmptyState(
                                colors: colors,
                                typo: typo,
                                l10n: l10n,
                                onAdd: () => _openAdd(
                                  identity.identityId!,
                                  colors,
                                  typo,
                                  l10n,
                                ),
                              ),
                            );
                          }
                          return _AddressList(
                            addresses: addresses,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                            identityId: identity.identityId!,
                            onAdd: () => _openAdd(
                              identity.identityId!,
                              colors,
                              typo,
                              l10n,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoIdentityState extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _NoIdentityState({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accentL,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: colors.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.savedAddressesEmailPrompt,
                    style: typo.bodyMedium.copyWith(
                      color: colors.textMid,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () async {
                final ok = await showEmailModal(context, ref);
                if (ok && context.mounted) {
                  ref.invalidate(savedAddressesProvider);
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.savedAddressesGetStarted,
                style: typo.labelLarge.copyWith(
                  color: colors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
      child: Column(
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
              onPressed: onAdd,
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
    );
  }
}

class _AddressList extends ConsumerWidget {
  final List<SavedAddress> addresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String identityId;
  final VoidCallback onAdd;

  const _AddressList({
    required this.addresses,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.identityId,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return _AddressTile(
                address: addr,
                colors: colors,
                typo: typo,
                onTap: () => Navigator.of(context).pop(
                  AddressResult(
                    displayName: addr.label,
                    fullAddress: addr.fullAddress,
                    lat: addr.latitude,
                    lng: addr.longitude,
                  ),
                ),
                onDelete: () async {
                  await ref
                      .read(savedAddressesProvider.notifier)
                      .remove(addr.id);
                },
              );
            },
          ),
        ),
        if (addresses.length < SavedAddressesNotifier.maxSavedAddresses)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add_rounded, color: colors.accent, size: 20),
                label: Text(
                  l10n.addSavedAddress,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.colors,
    required this.typo,
    required this.onTap,
    required this.onDelete,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.star_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForType(address.type),
                  color: colors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label,
                      style: typo.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.fullAddress,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.textSoft,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final HeyCabyColorTokens colors;
  const _DragHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
