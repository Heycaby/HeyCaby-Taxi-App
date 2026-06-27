import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';

class MarketplaceDriverScopePicker extends ConsumerWidget {
  const MarketplaceDriverScopePicker({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audience = ref.watch(bookingProvider).marketplaceDriverAudience;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.marketplaceDriverScopeTitle,
          style: typo.labelLarge.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _ScopeTile(
          colors: colors,
          typo: typo,
          title: l10n.marketplaceDriverScopeEveryone,
          selected: audience == MarketplaceDriverAudience.everyone,
          onTap: () => ref
              .read(bookingProvider.notifier)
              .setMarketplaceDriverAudience(MarketplaceDriverAudience.everyone),
        ),
        const SizedBox(height: 8),
        _ScopeTile(
          colors: colors,
          typo: typo,
          title: l10n.marketplaceDriverScopeMyDriversFirst,
          selected: audience == MarketplaceDriverAudience.myDriversFirst,
          onTap: () => ref.read(bookingProvider.notifier).setMarketplaceDriverAudience(
                MarketplaceDriverAudience.myDriversFirst,
              ),
        ),
        const SizedBox(height: 8),
        _ScopeTile(
          colors: colors,
          typo: typo,
          title: l10n.marketplaceDriverScopeMyDriversOnly,
          selected: audience == MarketplaceDriverAudience.myDriversOnly,
          onTap: () => ref.read(bookingProvider.notifier).setMarketplaceDriverAudience(
                MarketplaceDriverAudience.myDriversOnly,
              ),
        ),
      ],
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.colors,
    required this.typo,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected ? colors.accentL : colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? colors.accent : colors.textSoft,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
