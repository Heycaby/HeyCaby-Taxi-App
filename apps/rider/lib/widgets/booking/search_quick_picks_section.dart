import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/local_recent_addresses_provider.dart';
import '../../providers/saved_addresses_provider.dart';
import 'local_recent_addresses_sheet.dart';

int _savedTypeOrder(String type) {
  switch (type) {
    case 'home':
      return 0;
    case 'work':
      return 1;
    case 'gym':
      return 2;
    default:
      return 3;
  }
}

String _savedLabel(SavedAddress s, AppLocalizations l10n) {
  if (s.label.trim().isNotEmpty) return s.label;
  switch (s.type) {
    case 'home':
      return l10n.savedAddressLabelHome;
    case 'work':
      return l10n.savedAddressLabelWork;
    case 'gym':
      return l10n.savedAddressLabelGym;
    default:
      return s.label;
  }
}

AddressResult _fromSaved(SavedAddress s) {
  return AddressResult(
    displayName:
        s.label.isNotEmpty ? s.label : s.fullAddress.split(',').first.trim(),
    fullAddress: s.fullAddress,
    lat: s.latitude,
    lng: s.longitude,
  );
}

/// Saved places (server) + recent on device (local only) + browse actions.
class SearchQuickPicksSection extends ConsumerWidget {
  final ValueChanged<AddressResult> onPick;

  const SearchQuickPicksSection({super.key, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final savedAsync = ref.watch(savedAddressesProvider);
    final localRecentAsync = ref.watch(localRecentAddressesProvider);

    final saved = (savedAsync.valueOrNull ?? [])
        .where((s) => s.type != 'recent')
        .toList()
      ..sort(
          (a, b) => _savedTypeOrder(a.type).compareTo(_savedTypeOrder(b.type)));
    final pinned = saved.take(8).toList();

    final recentOnDevice = localRecentAsync.valueOrNull ?? [];

    Future<void> openRecentSheet() async {
      final r = await showLocalRecentAddressesSheet(context, ref);
      if (r != null) onPick(r);
    }

    Widget browseRow() {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/saved-addresses'),
              icon: Icon(Icons.bookmark_outline_rounded,
                  color: colors.accent, size: 20),
              label: Text(
                l10n.searchBrowseSavedPlaces,
                style: typo.labelMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: openRecentSheet,
              icon: Icon(Icons.history_rounded, color: colors.accent, size: 20),
              label: Text(
                l10n.searchBrowseRecentPlaces,
                style: typo.labelMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (pinned.isEmpty && recentOnDevice.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.searchStartTypingHint,
              style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.5),
            ),
            const SizedBox(height: 20),
            browseRow(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned.isNotEmpty) ...[
            Text(
              l10n.savedAddresses,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pinned.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final s = pinned[i];
                  return _QuickPickPlaceCard(
                    colors: colors,
                    typo: typo,
                    icon: s.type == 'home'
                        ? Icons.home_outlined
                        : s.type == 'work'
                            ? Icons.work_outline_rounded
                            : Icons.place_outlined,
                    title: _savedLabel(s, l10n),
                    onTap: () => onPick(_fromSaved(s)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (recentOnDevice.isNotEmpty) ...[
            Text(
              l10n.searchRecentOnDeviceSection,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...recentOnDevice.map(
              (r) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onPick(r),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.accentL,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: colors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            r.displayName.isNotEmpty
                                ? r.displayName
                                : r.fullAddress,
                            style: typo.bodyLarge.copyWith(color: colors.text),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: colors.textSoft, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          browseRow(),
          const SizedBox(height: 12),
          Text(
            l10n.searchStartTypingHint,
            style: typo.bodySmall.copyWith(color: colors.textSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _QuickPickPlaceCard extends StatelessWidget {
  const _QuickPickPlaceCard({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.accent, size: 18),
              const Spacer(),
              Text(
                title,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
