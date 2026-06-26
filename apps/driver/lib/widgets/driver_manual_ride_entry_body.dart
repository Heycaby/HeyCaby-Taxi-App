import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import 'driver_trip_planning_flow_common.dart';

class DriverManualRideSuggestion {
  const DriverManualRideSuggestion({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
}

/// **Manual Ride Entry** — off-app trip logging form.
class DriverManualRideEntryBody extends StatelessWidget {
  const DriverManualRideEntryBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.formKey,
    required this.pickupController,
    required this.dropoffController,
    required this.fareController,
    required this.passengerController,
    required this.paymentMethod,
    required this.saving,
    required this.loadingDropoffSuggestions,
    required this.dropoffSuggestions,
    required this.farePreviewText,
    required this.onDropoffChanged,
    required this.onSuggestionSelected,
    required this.onPaymentMethodChanged,
    required this.onFareChanged,
    required this.onSave,
    required this.onCancel,
    required this.onClose,
    required this.validateDropoff,
    required this.validateFare,
    this.dropoffFocusNode,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final GlobalKey<FormState> formKey;
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final TextEditingController fareController;
  final TextEditingController passengerController;
  final String paymentMethod;
  final bool saving;
  final bool loadingDropoffSuggestions;
  final List<DriverManualRideSuggestion> dropoffSuggestions;
  final String farePreviewText;
  final ValueChanged<String> onDropoffChanged;
  final ValueChanged<int> onSuggestionSelected;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onFareChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onClose;
  final FocusNode? dropoffFocusNode;
  final FormFieldValidator<String> validateDropoff;
  final FormFieldValidator<String> validateFare;

  InputDecoration _fieldDecoration({
    required String label,
    IconData? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      filled: true,
      fillColor: colors.backgroundAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverRadius.sm),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverTripPlanningFlowScaffold(
      title: DriverStrings.addManualRideTitle,
      colors: colors,
      typography: typography,
      leadingClose: true,
      onBack: onClose,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.md,
            DriverSpacing.screenEdge,
            bottomPad + DriverSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DriverTripPlanningSectionCard(
                  colors: colors,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.receipt_long_rounded, color: colors.primary),
                      const SizedBox(width: DriverSpacing.md),
                      Expanded(
                        child: Text(
                          DriverStrings.addManualRideExplainer,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverTripPlanningSectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route',
                        style: typography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      TextFormField(
                        controller: pickupController,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                        ),
                        decoration: _fieldDecoration(
                          label: DriverStrings.manualRidePickupLabel,
                          prefixIcon: Icons.trip_origin_rounded,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      TextFormField(
                        controller: dropoffController,
                        focusNode: dropoffFocusNode,
                        onChanged: onDropoffChanged,
                        validator: validateDropoff,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                        ),
                        decoration: _fieldDecoration(
                          label: DriverStrings.manualRideDropoffLabel,
                          prefixIcon: Icons.location_on_rounded,
                        ),
                      ),
                      if (loadingDropoffSuggestions) ...[
                        const SizedBox(height: DriverSpacing.sm),
                        LinearProgressIndicator(
                          minHeight: 2,
                          color: colors.primary,
                          backgroundColor: colors.border,
                        ),
                      ] else if (dropoffSuggestions.isNotEmpty) ...[
                        const SizedBox(height: DriverSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 170),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.backgroundAlt,
                              borderRadius: DriverRadius.smAll,
                              border: Border.all(color: colors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: dropoffSuggestions.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: colors.border,
                              ),
                              itemBuilder: (context, index) {
                                final item = dropoffSuggestions[index];
                                return DriverManualRideSuggestionTile(
                                  title: item.title,
                                  subtitle: item.subtitle,
                                  colors: colors,
                                  typography: typography,
                                  onTap: () => onSuggestionSelected(index),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverTripPlanningSectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip details',
                        style: typography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      TextFormField(
                        controller: fareController,
                        validator: validateFare,
                        onChanged: (_) => onFareChanged(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                        ),
                        decoration: _fieldDecoration(
                          label: DriverStrings.manualRideFareLabel,
                          prefixIcon: Icons.euro_rounded,
                          prefixText: 'EUR ',
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      TextFormField(
                        controller: passengerController,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                        ),
                        decoration: _fieldDecoration(
                          label: DriverStrings.manualRidePassengerLabel,
                          prefixIcon: Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverTripPlanningSectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.manualRidePaymentMethodLabel,
                        style: typography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'cash',
                            label: Text(DriverStrings.cash),
                          ),
                          ButtonSegment(
                            value: 'card',
                            label: Text(DriverStrings.card),
                          ),
                          ButtonSegment(
                            value: 'tikkie',
                            label: Text('Tikkie'),
                          ),
                        ],
                        selected: {paymentMethod},
                        onSelectionChanged: (selection) {
                          onPaymentMethodChanged(selection.first);
                        },
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DriverSpacing.md,
                          vertical: DriverSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.backgroundAlt,
                          borderRadius: DriverRadius.smAll,
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          farePreviewText,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DriverSpacing.xl),
                DriverTripPlanningSectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DriverButton(
                        label: DriverStrings.manualRideSaveCta,
                        colors: colors,
                        typography: typography,
                        loading: saving,
                        onPressed: saving ? null : onSave,
                        size: DriverButtonSize.lg,
                      ),
                      const SizedBox(height: DriverSpacing.sm),
                      DriverButton(
                        label: DriverStrings.cancel,
                        colors: colors,
                        typography: typography,
                        variant: DriverButtonVariant.ghost,
                        onPressed: saving ? null : onCancel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
