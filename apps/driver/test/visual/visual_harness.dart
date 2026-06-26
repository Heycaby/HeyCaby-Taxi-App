import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'golden_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// iPhone 15 Pro logical size — consistent golden viewport.
const kDriverGoldenSize = Size(393, 852);

const kDriverGoldenThemeId = kHeyCabyDriverProThemeId;

/// Wraps a widget with driver-pro theme for pixel-stable widget/golden tests.
class DriverVisualHarness extends StatelessWidget {
  const DriverVisualHarness({
    super.key,
    required this.child,
    this.themeId = kDriverGoldenThemeId,
    this.surfaceSize = kDriverGoldenSize,
  });

  final Widget child;
  final String themeId;
  final Size surfaceSize;

  @override
  Widget build(BuildContext context) {
    final colors = getTheme(themeId).colors;

    return ProviderScope(
      overrides: [
        colorsProvider.overrideWithValue(colors),
        typographyProvider.overrideWithValue(buildDriverGoldenTypography()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDriverGoldenMaterialTheme(colors),
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            devicePixelRatio: 1,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: Scaffold(
            backgroundColor: colors.bg,
            body: SizedBox(
              width: surfaceSize.width,
              height: surfaceSize.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
