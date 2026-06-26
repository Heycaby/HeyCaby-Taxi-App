import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_quick_answers_body.dart';

class DriverFaqScreen extends ConsumerWidget {
  const DriverFaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverQuickAnswersBody(
      colors: colors,
      typography: typography,
      sections: kDriverFaqSections,
      onBack: () => context.pop(),
    );
  }
}
