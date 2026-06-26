import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ledger_flow_common.dart';

/// **Trip Receipt** — one ride, full detail.
class DriverTripReceiptBody extends StatelessWidget {
  const DriverTripReceiptBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.notFound,
    required this.fareLabel,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTone,
    required this.details,
    required this.onBack,
    this.footerSections = const [],
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final bool notFound;
  final String fareLabel;
  final String subtitle;
  final String statusLabel;
  final DriverStatusTone statusTone;
  final List<DriverLedgerDetailItem> details;
  final VoidCallback onBack;
  final List<Widget> footerSections;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverLedgerFlowScaffold(
      title: DriverStrings.rideDetails,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(child: DriverSkeleton(colors: colors, width: 200, height: 24))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : notFound
                  ? DriverEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: DriverStrings.rideDetailsNotFound,
                      colors: colors,
                      typography: typography,
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        DriverSpacing.screenEdge,
                        DriverSpacing.md,
                        DriverSpacing.screenEdge,
                        bottomPad + DriverSpacing.lg,
                      ),
                      children: [
                        DriverLedgerReceiptHero(
                          fareLabel: fareLabel,
                          subtitle: subtitle,
                          statusLabel: statusLabel,
                          statusTone: statusTone,
                          colors: colors,
                          typography: typography,
                        ),
                        const SizedBox(height: DriverSpacing.lg),
                        DriverLedgerDetailList(
                          items: details,
                          colors: colors,
                          typography: typography,
                        ),
                        ...footerSections,
                      ],
                    ),
    );
  }
}
