import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/local_recent_addresses_provider.dart';

/// Bottom sheet listing device-local recent addresses (max 10).
Future<AddressResult?> showLocalRecentAddressesSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(localRecentAddressesProvider.notifier).refreshFromDisk();
  if (!context.mounted) return null;
  return showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.72;
      return SizedBox(
        height: h,
        child: const _LocalRecentSheetBody(),
      );
    },
  );
}

class _LocalRecentSheetBody extends ConsumerWidget {
  const _LocalRecentSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(localRecentAddressesProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accentL,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.history_rounded,
                        color: colors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.searchBrowseRecentPlaces,
                          style: typo.headingMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.searchRecentOnDeviceSubtitle,
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
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(l10n.error, style: typo.bodyMedium),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsetsDirectional.all(24),
                      child: Center(
                        child: Text(
                          l10n.searchNoLocalRecentsYet,
                          textAlign: TextAlign.center,
                          style: typo.bodyMedium.copyWith(
                            color: colors.textMid,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colors.border,
                    ),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(r),
                        contentPadding:
                            const EdgeInsetsDirectional.symmetric(vertical: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.accentL,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.history_rounded,
                              color: colors.accent, size: 22),
                        ),
                        title: Text(
                          r.displayName.isNotEmpty
                              ? r.displayName
                              : r.fullAddress.split(',').first.trim(),
                          style: typo.bodyLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: r.fullAddress.isNotEmpty
                            ? Text(
                                r.fullAddress,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
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
}
