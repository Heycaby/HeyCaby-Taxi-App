import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/saved_addresses_provider.dart';
import '../services/booking_saved_place_shortcut.dart';
import 'email_modal.dart';
import 'saved_addresses_add_sheet.dart';
import 'saved_places_premium_widgets.dart';

String? _savedAddressesErrorMessage(AppLocalizations l10n, Object error) {
  final message = error.toString();
  if (message.contains('rider_identity_not_found') ||
      message.contains('not_authenticated')) {
    return l10n.savedAddressesSessionRequired;
  }
  return l10n.error;
}

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

  Future<void> _openAdd(
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

  Widget _emptyOrErrorBody({
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required AppLocalizations l10n,
    String? errorMessage,
  }) {
    return SavedPlacesEmptyState(
      colors: colors,
      typo: typo,
      l10n: l10n,
      errorMessage: errorMessage,
      onRetry: errorMessage == null
          ? null
          : () => ref.read(savedAddressesProvider.notifier).refresh(),
      showInlineAddButton: false,
      onAdd: () => _openAdd(colors, typo, l10n),
      onShortcut: (type) => _openAdd(
        colors,
        typo,
        l10n,
        initialType: type,
      ),
    );
  }

  Widget _sheetAddBar({
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required AppLocalizations l10n,
    required VoidCallback onAdd,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, color: colors.onAccent, size: 20),
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
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
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
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.accent.withValues(alpha: 0.12),
                    colors.bg.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: true,
            child: Column(
              children: [
                SavedPlacesDragHandle(colors: colors),
                identityAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (identity) {
                    final count = addressesAsync.valueOrNull?.length;
                    return SavedPlacesSheetHeader(
                      colors: colors,
                      typo: typo,
                      title: l10n.savedAddresses,
                      subtitle: l10n.savedPlacesSheetSubtitle,
                      placeCount: identity.hasSession ? count : null,
                      onClose: () => Navigator.of(context).pop(),
                    );
                  },
                ),
                Expanded(
                  child: identityAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (identity) {
                      if (!identity.hasSession) {
                        return SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.only(bottom: 16),
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
                        error: (err, _) => _emptyOrErrorBody(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          errorMessage: _savedAddressesErrorMessage(l10n, err),
                        ),
                        data: (addresses) {
                          if (addresses.isEmpty) {
                            return _emptyOrErrorBody(
                              colors: colors,
                              typo: typo,
                              l10n: l10n,
                            );
                          }
                          return _AddressList(
                            addresses: addresses,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          );
                        },
                      );
                    },
                  ),
                ),
                identityAsync.maybeWhen(
                  data: (identity) {
                    if (!identity.hasSession) return const SizedBox.shrink();
                    final count = addressesAsync.valueOrNull?.length ?? 0;
                    if (count >= SavedAddressesNotifier.maxSavedAddresses) {
                      return const SizedBox.shrink();
                    }
                    return _sheetAddBar(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      onAdd: () => _openAdd(colors, typo, l10n),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
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
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accentL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mail_outline_rounded,
                      color: colors.accent, size: 20),
                ),
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

class _AddressList extends ConsumerWidget {
  final List<SavedAddress> addresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _AddressList({
    required this.addresses,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
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
              navigation: SavedPlaceBookingNavigation.closeSheet,
            );
          },
          onEdit: () => showEditSavedAddressSheet(
            context,
            colors: colors,
            typo: typo,
            l10n: l10n,
            address: addr,
          ),
          onDelete: () async {
            await ref.read(savedAddressesProvider.notifier).remove(addr.id);
          },
        );
      },
    );
  }
}
