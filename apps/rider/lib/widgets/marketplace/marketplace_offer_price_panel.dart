import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/marketplace_pricing_provider.dart';

class MarketplaceOfferPricePanel extends ConsumerStatefulWidget {
  const MarketplaceOfferPricePanel({
    super.key,
    required this.bidAmount,
    required this.hasAddresses,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onBidChanged,
  });

  final int bidAmount;
  final bool hasAddresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<int> onBidChanged;

  @override
  ConsumerState<MarketplaceOfferPricePanel> createState() =>
      _MarketplaceOfferPricePanelState();
}

class _MarketplaceOfferPricePanelState
    extends ConsumerState<MarketplaceOfferPricePanel> {
  late final TextEditingController _amountController;
  final FocusNode _amountFocus = FocusNode();
  bool _isEditingAmount = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '${widget.bidAmount}');
    _amountFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _amountFocus.removeListener(_onFocusChange);
    _amountFocus.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isEditingAmount = _amountFocus.hasFocus);
  }

  @override
  void didUpdateWidget(covariant MarketplaceOfferPricePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditingAmount && oldWidget.bidAmount != widget.bidAmount) {
      _amountController.text = '${widget.bidAmount}';
    }
  }

  MarketplaceBidBounds _bounds(double? refFare) => marketplaceBidBounds(
        referenceFareEuro: refFare,
        currentBidEuro: widget.bidAmount,
      );

  void _applyBid(int value, MarketplaceBidBounds bounds) {
    final clamped = clampMarketplaceBid(value, bounds);
    if (clamped != widget.bidAmount) {
      HapticService.selectionClick();
      widget.onBidChanged(clamped);
    }
    if (!_isEditingAmount) {
      _amountController.text = '$clamped';
    }
  }

  void _step(int delta, MarketplaceBidBounds bounds) {
    final step = marketplaceBidStepFor(widget.bidAmount);
    _applyBid(widget.bidAmount + delta * step, bounds);
  }

  void _commitTypedAmount(MarketplaceBidBounds bounds) {
    final parsed = int.tryParse(_amountController.text.trim());
    if (parsed != null) {
      _applyBid(parsed, bounds);
    } else {
      _amountController.text = '${widget.bidAmount}';
    }
    _amountFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRef = ref.watch(marketplaceReferenceFareEuroProvider);
    final refFare = asyncRef.valueOrNull;
    final bounds = _bounds(refFare);
    final typical = asyncRef.when(
      data: (fare) => fare != null && fare > 0 && widget.hasAddresses
          ? formatTypicalFareRange(fare)
          : '—',
      loading: () => widget.hasAddresses ? '…' : '—',
      error: (_, __) => '—',
    );

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: widget.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.colors.border.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.l10n.marketplaceYourBid,
            style: widget.typo.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: widget.colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.l10n.marketplaceDriversAcceptHint,
            style: widget.typo.bodySmall.copyWith(
              color: widget.colors.textMid,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StepButton(
                colors: widget.colors,
                icon: Icons.remove_rounded,
                onTap: widget.bidAmount > bounds.minEuro
                    ? () => _step(-1, bounds)
                    : null,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.lightTap();
                    _amountFocus.requestFocus();
                    _amountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _amountController.text.length,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.colors.bgAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isEditingAmount
                            ? widget.colors.accent
                            : widget.colors.border.withValues(alpha: 0.5),
                        width: _isEditingAmount ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '€',
                          style: widget.typo.headingLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            color: widget.colors.accent,
                            fontSize: 36,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            textAlign: TextAlign.center,
                            style: widget.typo.headingLarge.copyWith(
                              fontWeight: FontWeight.w900,
                              color: widget.colors.accent,
                              fontSize: 36,
                              height: 1.1,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: widget.l10n.marketplacePriceHint,
                              hintStyle: widget.typo.headingLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                color: widget.colors.textSoft,
                                fontSize: 36,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _commitTypedAmount(bounds),
                            onEditingComplete: () => _commitTypedAmount(bounds),
                            onChanged: (raw) {
                              final parsed = int.tryParse(raw);
                              if (parsed != null &&
                                  parsed >= kMarketplaceBidMinEuro &&
                                  parsed <= kMarketplaceBidMaxEuro) {
                                widget.onBidChanged(parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _StepButton(
                colors: widget.colors,
                icon: Icons.add_rounded,
                onTap: widget.bidAmount < bounds.maxEuro
                    ? () => _step(1, bounds)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.l10n.marketplaceEnterCustomPrice,
            textAlign: TextAlign.center,
            style: widget.typo.labelSmall.copyWith(
              color: widget.colors.textSoft,
            ),
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.colors.accent,
              inactiveTrackColor: widget.colors.border.withValues(alpha: 0.5),
              thumbColor: widget.colors.accent,
              overlayColor: widget.colors.accent.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
            ),
            child: Slider(
              value: widget.bidAmount
                  .toDouble()
                  .clamp(bounds.minEuro.toDouble(), bounds.maxEuro.toDouble()),
              min: bounds.minEuro.toDouble(),
              max: bounds.maxEuro.toDouble(),
              onChanged: (v) => _applyBid(v.round(), bounds),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMarketplaceEuro(bounds.minEuro.toDouble()),
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textSoft,
                ),
              ),
              Text(
                widget.l10n.marketplaceTypicalRangeLabel(typical),
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatMarketplaceEuro(bounds.maxEuro.toDouble()),
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: widget.bidAmount < bounds.maxEuro
                  ? () => _step(2, bounds)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: widget.colors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.l10n.marketplaceBoostOfferSubtitle,
                style: widget.typo.labelSmall.copyWith(
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

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.colors,
    required this.icon,
    this.onTap,
  });

  final HeyCabyColorTokens colors;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: colors.bgAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: enabled ? colors.text : colors.textSoft,
            size: 22,
          ),
        ),
      ),
    );
  }
}
