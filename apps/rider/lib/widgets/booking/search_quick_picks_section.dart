import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/local_recent_addresses_provider.dart';
import '../../providers/saved_addresses_provider.dart';
import '../home/home_ride_again_section.dart';
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
      return _SearchBrowseLinks(
        colors: colors,
        typo: typo,
        savedLabel: l10n.searchBrowseSavedPlaces,
        recentLabel: l10n.searchBrowseRecentPlaces,
        onBrowseSaved: () => context.push('/saved-addresses?from=search'),
        onBrowseRecent: openRecentSheet,
      );
    }

    if (pinned.isEmpty && recentOnDevice.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeRideAgainSection(colors: colors, typo: typo, l10n: l10n),
            Text(
              l10n.searchStartTypingHint,
              style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.5),
            ),
            const SizedBox(height: 14),
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
          HomeRideAgainSection(colors: colors, typo: typo, l10n: l10n),
          if (pinned.isNotEmpty) ...[
            Text(
              l10n.savedAddresses,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pinned.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = pinned[i];
                  return _QuickPickPlacePill(
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
            const SizedBox(height: 8),
          ],
          browseRow(),
          const SizedBox(height: 8),
          Text(
            l10n.searchStartTypingHint,
            style: typo.bodySmall.copyWith(color: colors.textSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Compact secondary links — saved places & full recent list.
class _SearchBrowseLinks extends StatelessWidget {
  const _SearchBrowseLinks({
    required this.colors,
    required this.typo,
    required this.savedLabel,
    required this.recentLabel,
    required this.onBrowseSaved,
    required this.onBrowseRecent,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String savedLabel;
  final String recentLabel;
  final VoidCallback onBrowseSaved;
  final VoidCallback onBrowseRecent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: [
          _BrowseLink(
            colors: colors,
            typo: typo,
            icon: Icons.bookmark_outline_rounded,
            label: savedLabel,
            onTap: onBrowseSaved,
          ),
          Text(
            '·',
            style: typo.labelLarge.copyWith(color: colors.textSoft),
          ),
          _BrowseLink(
            colors: colors,
            typo: typo,
            icon: Icons.history_rounded,
            label: recentLabel,
            onTap: onBrowseRecent,
          ),
        ],
      ),
    );
  }
}

class _BrowseLink extends StatelessWidget {
  const _BrowseLink({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticService.lightTap();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: typo.labelLarge.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPickPlacePill extends StatelessWidget {
  const _QuickPickPlacePill({
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
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border.withValues(alpha: 0.85)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: typo.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
