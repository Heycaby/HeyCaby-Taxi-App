import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../../providers/booking_provider.dart';

enum SearchAddressFocus { pickup, destination }

class SearchAddressHeader extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final BookingMode mode;
  final TextEditingController pickupController;
  final TextEditingController destinationController;
  final FocusNode pickupFocus;
  final FocusNode destinationFocus;
  final ValueChanged<String> onPickupChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onSwap;
  final VoidCallback onBack;
  final VoidCallback onWhenTap;
  final DateTime? scheduledAt;
  final bool pickupLoading;

  const SearchAddressHeader({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.mode,
    required this.pickupController,
    required this.destinationController,
    required this.pickupFocus,
    required this.destinationFocus,
    required this.onPickupChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.onBack,
    required this.onWhenTap,
    this.scheduledAt,
    this.pickupLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleSummary = scheduledAt != null
        ? '${scheduledAt!.day}/${scheduledAt!.month} ${scheduledAt!.hour}:${scheduledAt!.minute.toString().padLeft(2, '0')}'
        : l10n.laterButton;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        HeyCabySpacing.screenEdge,
        4,
        HeyCabySpacing.screenEdge,
        HeyCabySpacing.component,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  foregroundColor: colors.text,
                  backgroundColor: colors.card,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 10),
                  child: Text(
                    l10n.whereAreYouGoing,
                    style: typo.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HeyCabySpacing.sectionMedium),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: _SearchDotColumn(colors: colors),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _SearchAddressField(
                        controller: pickupController,
                        focusNode: pickupFocus,
                        hint: l10n.pickup,
                        colors: colors,
                        typo: typo,
                        onChanged: onPickupChanged,
                        isLoading: pickupLoading,
                        loadingHint: l10n.marketplaceLocatingYou,
                      ),
                      Divider(height: 1, thickness: 1, color: colors.border.withValues(alpha: 0.5)),
                      _SearchAddressField(
                        controller: destinationController,
                        focusNode: destinationFocus,
                        hint: l10n.destination,
                        colors: colors,
                        typo: typo,
                        onChanged: onDestinationChanged,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSwap,
                  icon: Icon(Icons.swap_vert_rounded, color: colors.accent, size: 24),
                  style: IconButton.styleFrom(
                    foregroundColor: colors.accent,
                    backgroundColor: colors.accentL,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HeyCabySpacing.component),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onWhenTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  color: mode == BookingMode.scheduled
                      ? colors.accentL
                      : colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: mode == BookingMode.scheduled
                        ? colors.accent
                        : colors.border.withValues(alpha: 0.7),
                    width: mode == BookingMode.scheduled ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: mode == BookingMode.scheduled
                              ? colors.accent.withValues(alpha: 0.18)
                              : colors.bgAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: mode == BookingMode.scheduled
                              ? colors.accent
                              : colors.textMid,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.whenRowLabel,
                              style: typo.titleSmall.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode == BookingMode.scheduled
                                  ? scheduleSummary
                                  : l10n.searchScheduleHint,
                              style: typo.bodySmall.copyWith(
                                color: colors.textMid,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSoft,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchDotColumn extends StatelessWidget {
  final HeyCabyColorTokens colors;
  const _SearchDotColumn({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.success, width: 2.5),
          ),
        ),
        Container(
          width: 2,
          height: 22,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.error,
            boxShadow: [
              BoxShadow(
                color: colors.error.withValues(alpha: 0.35),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchAddressField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<String> onChanged;
  final bool isLoading;
  final String? loadingHint;

  const _SearchAddressField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.colors,
    required this.typo,
    required this.onChanged,
    this.isLoading = false,
    this.loadingHint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: !isLoading,
      maxLines: 1,
      inputFormatters: [LengthLimitingTextInputFormatter(200)],
      style: typo.bodyLarge.copyWith(
        color: colors.text,
        fontWeight: FontWeight.w500,
      ),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: isLoading ? (loadingHint ?? hint) : hint,
        hintStyle: typo.bodyLarge.copyWith(color: colors.textSoft),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 14, 8, 14),
        suffixIcon: isLoading
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                  ),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    );
  }
}

class AddressSearchSuggestionsList extends StatelessWidget {
  final List<AddressResult> suggestions;
  final bool isLoading;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<AddressResult> onTap;
  final bool shrinkWrap;

  const AddressSearchSuggestionsList({
    super.key,
    required this.suggestions,
    required this.isLoading,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return shrinkWrap
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2,
                ),
              ),
            )
          : Center(
              child: CircularProgressIndicator(
                color: colors.accent,
                strokeWidth: 2,
              ),
            );
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(top: 8),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 56,
        color: colors.border,
      ),
      itemBuilder: (_, index) {
        final item = suggestions[index];
        return _AddressSuggestionTile(
          result: item,
          colors: colors,
          typo: typo,
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class _AddressSuggestionTile extends StatelessWidget {
  final AddressResult result;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _AddressSuggestionTile({
    required this.result,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.accentL,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.place_rounded, color: colors.accent, size: 22),
      ),
      title: Text(
        result.displayName,
        style: typo.bodyLarge.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: result.fullAddress.isNotEmpty &&
              result.fullAddress != result.displayName
          ? Text(
              result.fullAddress,
              style: typo.bodySmall.copyWith(color: colors.textSoft, height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
  }
}
