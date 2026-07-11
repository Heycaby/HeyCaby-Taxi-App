import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/ride_matching_variant.dart';

/// Minimal recovery UI: one primary CTA + progressive "more options".
class MatchingRecoverySheet extends StatefulWidget {
  const MatchingRecoverySheet({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.title,
    required this.body,
    required this.variant,
    required this.onNotifyMe,
    required this.onSchedule,
    required this.onMarketplace,
    this.scrollController,
    this.showTryAgain = false,
    this.onTryAgain,
    this.initiallyExpanded = false,
    this.onDismiss,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String title;
  final String body;
  final RideMatchingVariant variant;
  final VoidCallback onNotifyMe;
  final VoidCallback onSchedule;
  final VoidCallback onMarketplace;
  final ScrollController? scrollController;
  final bool showTryAgain;
  final VoidCallback? onTryAgain;
  final bool initiallyExpanded;
  final VoidCallback? onDismiss;

  @override
  State<MatchingRecoverySheet> createState() => _MatchingRecoverySheetState();
}

class _MatchingRecoverySheetState extends State<MatchingRecoverySheet> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final l10n = widget.l10n;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      tintColor: colors.card,
      borderColor: colors.border.withValues(alpha: 0.35),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16 + bottomInset),
        shrinkWrap: widget.scrollController == null,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.body,
                      style: typo.bodyLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (widget.showTryAgain && widget.onTryAgain != null)
            FilledButton(
              onPressed: () {
                HapticService.mediumTap();
                widget.onTryAgain!();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.tryAgain,
                style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          if (widget.onDismiss != null) ...[
            if (widget.showTryAgain) const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                HapticService.lightTap();
                widget.onDismiss!();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: colors.text,
                side: BorderSide(color: colors.border.withValues(alpha: 0.85)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.searchExpiredGoHome,
                style: typo.labelLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (!_expanded && !widget.initiallyExpanded) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: Text(
                  l10n.searchSeeOptions,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_expanded || widget.initiallyExpanded) ...[
            const SizedBox(height: 4),
            MatchingRecoverySecondaryLinks(
              colors: colors,
              typo: typo,
              l10n: l10n,
              variant: widget.variant,
              onNotifyMe: widget.onNotifyMe,
              onSchedule: widget.onSchedule,
              onMarketplace: widget.onMarketplace,
              emphasizeNotify: widget.showTryAgain,
            ),
          ],
        ],
      ),
    );
  }
}

/// Text-link row for secondary recovery paths.
class MatchingRecoverySecondaryLinks extends StatelessWidget {
  const MatchingRecoverySecondaryLinks({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.variant,
    required this.onNotifyMe,
    required this.onSchedule,
    required this.onMarketplace,
    this.emphasizeNotify = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final RideMatchingVariant variant;
  final VoidCallback onNotifyMe;
  final VoidCallback onSchedule;
  final VoidCallback onMarketplace;
  final bool emphasizeNotify;

  @override
  Widget build(BuildContext context) {
    final links = <({String label, VoidCallback onTap})>[];

    switch (variant) {
      case RideMatchingVariant.instant:
        if (emphasizeNotify) {
          links.add((label: l10n.notifyMeWhenFound, onTap: onNotifyMe));
        }
        links.add((label: l10n.scheduleRideInstead, onTap: onSchedule));
        links.add((label: l10n.homeTaxiTerugTitle, onTap: onMarketplace));
      case RideMatchingVariant.marketplace:
      case RideMatchingVariant.terug:
        links.add((label: l10n.scheduleRideInstead, onTap: onSchedule));
        links.add((label: l10n.notifyMeWhenFound, onTap: onNotifyMe));
      case RideMatchingVariant.scheduled:
        links.add((label: l10n.notifyMeWhenFound, onTap: onNotifyMe));
        links.add((label: l10n.homeTaxiTerugTitle, onTap: onMarketplace));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        for (var i = 0; i < links.length; i++) ...[
          _LinkChip(
            colors: colors,
            typo: typo,
            label: links[i].label,
            onTap: links[i].onTap,
          ),
          if (i != links.length - 1)
            Text(
              '·',
              style: typo.labelLarge.copyWith(color: colors.textSoft),
            ),
        ],
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.colors,
    required this.typo,
    required this.label,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
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
          horizontal: 4,
          vertical: 6,
        ),
        child: Text(
          label,
          style: typo.labelLarge.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
