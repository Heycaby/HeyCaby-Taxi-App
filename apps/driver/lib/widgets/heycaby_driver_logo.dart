import 'package:flutter/material.dart';

import '../constants/driver_brand_assets.dart';

/// HeyCaby wordmark — yellow text, transparent background.
class HeyCabyDriverLogo extends StatelessWidget {
  const HeyCabyDriverLogo({
    super.key,
    this.width = 200,
    this.height,
    this.semanticsLabel = 'HeyCaby',
    this.color,
  });

  final double width;
  final double? height;
  final String semanticsLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Image.asset(
        DriverBrandAssets.logo,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
      ),
    );
  }
}

/// Square app-mark (black tile + wordmark) for launcher icons only.
class HeyCabyDriverAppMark extends StatelessWidget {
  const HeyCabyDriverAppMark({
    super.key,
    this.size = 120,
    this.borderRadius = 24,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'HeyCaby',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          DriverBrandAssets.appIconSource,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
