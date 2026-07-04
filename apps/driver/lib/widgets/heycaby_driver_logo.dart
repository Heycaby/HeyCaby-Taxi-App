import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/driver_brand_assets.dart';

/// HeyCaby wordmark. Pass [color] when a screen needs the green driver mark.
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
      child: SvgPicture.asset(
        DriverBrandAssets.logo,
        width: width,
        height: height,
        fit: BoxFit.contain,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
  }
}

/// Circular HeyCaby C-mark for compact brand moments.
class HeyCabyDriverMark extends StatelessWidget {
  const HeyCabyDriverMark({
    super.key,
    this.size = 56,
    this.semanticsLabel = 'HeyCaby',
  });

  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SvgPicture.asset(
        DriverBrandAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
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
