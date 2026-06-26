import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/driver_runtime_models.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_readiness_routes.dart';
import '../widgets/driver_dynamic_checklist_card.dart';
import '../widgets/driver_readiness_gate_body.dart';

class DriverRuntimeGateArgs {
  const DriverRuntimeGateArgs({
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaRoute,
    this.secondaryLabel,
    this.secondaryRoute,
    this.checklist = const [],
  });

  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;
  final List<DriverReadinessItem> checklist;
}

/// **Readiness Gate** — show what's blocking go-live.
class DriverRuntimeGateScreen extends ConsumerWidget {
  const DriverRuntimeGateScreen({super.key, required this.args});

  final DriverRuntimeGateArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);
    final colors = DriverColors.fromTheme(themeColors);
    final typography = DriverTypography.fromTheme(themeTypo);

    return DriverReadinessGateBody(
      colors: colors,
      typography: typography,
      title: args.title,
      body: args.body,
      checklist: args.checklist.isEmpty
          ? null
          : DriverDynamicChecklistCard(
              items: args.checklist,
              colors: themeColors,
              typo: themeTypo,
              onIncompleteItemTapped: (item) {
                final route = flutterRouteForReadinessItem(item);
                if (route != null) {
                  context.push(route);
                }
              },
            ),
      primaryLabel: args.ctaLabel,
      onPrimary: args.ctaRoute != null ? () => context.go(args.ctaRoute!) : null,
      secondaryLabel: args.secondaryLabel,
      onSecondary:
          args.secondaryRoute != null ? () => context.go(args.secondaryRoute!) : null,
      onBackHome: () => context.go('/driver'),
      onBack: () => context.pop(),
    );
  }
}
