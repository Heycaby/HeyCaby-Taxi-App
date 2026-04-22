import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import 'driver_hub_sections.dart';

/// Driver Hub bottom sheet — 85% height, drag handle, 4 sections + Pro tools.
class DriverHubSheet extends ConsumerWidget {
  const DriverHubSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);

    String statusLabel;
    Color statusColor;
    switch (driver.appState) {
      case DriverAppState.onlineAvailable:
      case DriverAppState.reviewingRequest:
      case DriverAppState.acceptingRide:
      case DriverAppState.assigned:
      case DriverAppState.arrived:
      case DriverAppState.inProgress:
      case DriverAppState.completingRide:
      case DriverAppState.completed:
        statusLabel = DriverStrings.online;
        statusColor = colors.success;
        break;
      case DriverAppState.onBreak:
        statusLabel = DriverStrings.onBreak;
        statusColor = colors.warning;
        break;
      default:
        statusLabel = DriverStrings.offline;
        statusColor = colors.textSoft;
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DriverStrings.driverHub,
                                  style: typo.headingMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DriverStrings.driverHubSubtitle,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: typo.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubEarningsTargetSection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubRatesSection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubSafetySection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubHelpSection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: DriverHubPowerUnionRows(colors: colors, typo: typo),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox(height: MediaQuery.of(context).padding.bottom),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final HeyCabyColorTokens colors;

  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: colors.border);
  }
}
