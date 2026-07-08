import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../screens/location_required_screen.dart';
import '../../services/nearby_supply_service.dart';

enum HomeSupplyInsightTone { empty, moderate, far, nearby }

class HomeSupplyInsightMessage {
  const HomeSupplyInsightMessage({
    required this.title,
    required this.subtitle,
    required this.tone,
    this.actionable = false,
  });

  final String title;
  final String subtitle;
  final HomeSupplyInsightTone tone;
  final bool actionable;
}

/// Live supply copy from SDA zone snapshot (5 / 10 / 20 km rings).
HomeSupplyInsightMessage? resolveHomeSupplyInsight({
  required RiderSupplySnapshot snapshot,
  required AppLocalizations l10n,
}) {
  if (!snapshot.rpcSucceeded) return null;

  // Strong nearby supply — stay out of the way.
  if (snapshot.zone1Count >= 3) return null;

  if (snapshot.totalCount == 0) {
    return HomeSupplyInsightMessage(
      title: l10n.homeSupplyNoneTitle,
      subtitle: l10n.homeSupplyNoneSubtitle,
      tone: HomeSupplyInsightTone.empty,
      actionable: true,
    );
  }

  if (snapshot.zone1Count > 0) {
    final km = _formatKm(snapshot.closestKm);
    return HomeSupplyInsightMessage(
      title: l10n.homeSupplyNearbyTitle(snapshot.zone1Count),
      subtitle: km != null
          ? l10n.homeSupplyNearbySubtitle(km)
          : l10n.homeSupplyNearbySubtitleShort,
      tone: HomeSupplyInsightTone.nearby,
    );
  }

  if (snapshot.zone2Count > 0) {
    return HomeSupplyInsightMessage(
      title: l10n.homeSupplyZoneEmptyTitle,
      subtitle: l10n.homeSupplyZoneEmptySubtitle(snapshot.zone2Count),
      tone: HomeSupplyInsightTone.moderate,
      actionable: true,
    );
  }

  final km = _formatKm(snapshot.closestKm) ?? '10';
  return HomeSupplyInsightMessage(
    title: l10n.homeSupplyFarTitle,
    subtitle: l10n.homeSupplyFarSubtitle(snapshot.totalCount, km),
    tone: HomeSupplyInsightTone.far,
    actionable: true,
  );
}

String? _formatKm(double? km) {
  if (km == null || km.isNaN || km <= 0) return null;
  if (km < 10) return km.toStringAsFixed(1);
  return km.round().toString();
}

class HomeSupplyInsightCard extends ConsumerWidget {
  const HomeSupplyInsightCard({
    super.key,
    required this.snapshot,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final RiderSupplySnapshot snapshot;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = resolveHomeSupplyInsight(snapshot: snapshot, l10n: l10n);
    if (message == null) return const SizedBox.shrink();

    final palette = _paletteFor(colors, message.tone);
    final onTap = message.actionable
        ? () => _openAlternatives(context, ref)
        : null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 0),
      child: Material(
        color: palette.background,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 3),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: palette.dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette.dot.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.subtitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.actionable)
                  Icon(Icons.chevron_right_rounded,
                      color: colors.textSoft, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAlternatives(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
          child: GlassPanel(
            colors: colors,
            typography: typo,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
            borderRadius: BorderRadius.circular(24),
            tintColor: colors.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.schedule_rounded, color: colors.accent),
                  title: Text(
                    l10n.homeScheduleLaterTitle,
                    style: typo.titleSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.homeScheduleLaterSubtitle,
                    style: typo.bodySmall.copyWith(color: colors.textMid),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final ok = await ensureLocationForBooking(
                      context: context,
                      ref: ref,
                    );
                    if (!ok) return;
                    ref.read(bookingProvider.notifier).setScheduled();
                    if (context.mounted) context.go('/search');
                  },
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.6)),
                ListTile(
                  leading: Icon(Icons.groups_outlined, color: colors.accent),
                  title: Text(
                    l10n.marketplace,
                    style: typo.titleSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.marketplaceTagline,
                    style: typo.bodySmall.copyWith(color: colors.textMid),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(bookingProvider.notifier).setMarketplace();
                    context.push('/marketplace');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SupplyPalette {
  const _SupplyPalette({
    required this.background,
    required this.border,
    required this.dot,
  });

  final Color background;
  final Color border;
  final Color dot;
}

_SupplyPalette _paletteFor(
  HeyCabyColorTokens colors,
  HomeSupplyInsightTone tone,
) {
  switch (tone) {
    case HomeSupplyInsightTone.nearby:
      return _SupplyPalette(
        background: colors.accentL.withValues(alpha: 0.55),
        border: colors.accent.withValues(alpha: 0.18),
        dot: colors.success,
      );
    case HomeSupplyInsightTone.moderate:
      return _SupplyPalette(
        background: colors.warning.withValues(alpha: 0.10),
        border: colors.warning.withValues(alpha: 0.28),
        dot: colors.warning,
      );
    case HomeSupplyInsightTone.far:
      return _SupplyPalette(
        background: colors.card,
        border: colors.border.withValues(alpha: 0.85),
        dot: colors.textMid,
      );
    case HomeSupplyInsightTone.empty:
      return _SupplyPalette(
        background: colors.bgAlt,
        border: colors.border.withValues(alpha: 0.85),
        dot: colors.error.withValues(alpha: 0.85),
      );
  }
}
