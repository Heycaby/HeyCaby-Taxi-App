import 'package:flutter/material.dart';

import '../theme/driver_typography.dart';
import 'heycaby_driver_logo.dart';

/// Localized copy for the brand moment splash.
class DriverBrandMomentCopy {
  const DriverBrandMomentCopy({
    required this.pillar1,
    required this.pillar2,
    required this.pillar3,
    required this.pillar4,
    required this.continueLabel,
    required this.skipLabel,
  });

  final String pillar1;
  final String pillar2;
  final String pillar3;
  final String pillar4;
  final String continueLabel;
  final String skipLabel;
}

/// **Brand Moment** — logo + value pillars (presentation only).
class DriverBrandMomentBody extends StatelessWidget {
  const DriverBrandMomentBody({
    super.key,
    required this.typography,
    required this.copy,
    required this.isIOS,
    required this.exitOpacity,
    required this.logoFade,
    required this.logoScale,
    required this.glowOpacity,
    required this.pillar1Opacity,
    required this.pillar1Slide,
    required this.pillar2Opacity,
    required this.pillar2Slide,
    required this.pillar3Opacity,
    required this.pillar3Slide,
    required this.pillar4Opacity,
    required this.pillar4Slide,
    required this.canContinue,
    required this.loadingProgress,
    required this.onContinue,
  });

  final DriverTypography typography;
  final DriverBrandMomentCopy copy;
  final bool isIOS;
  final double exitOpacity;
  final double logoFade;
  final double logoScale;
  final double glowOpacity;
  final double pillar1Opacity;
  final double pillar1Slide;
  final double pillar2Opacity;
  final double pillar2Slide;
  final double pillar3Opacity;
  final double pillar3Slide;
  final double pillar4Opacity;
  final double pillar4Slide;
  final bool canContinue;
  final double loadingProgress;
  final VoidCallback onContinue;

  static const _splashBackground = Color(0xFFF5F7F6);
  static const _splashText = Color(0xFF111827);
  static const _splashAccent = Color(0xFF00A651);

  @override
  Widget build(BuildContext context) {
    final radius = isIOS ? 22.0 : 16.0;
    final buttonHeight = isIOS ? 54.0 : 52.0;

    return Scaffold(
      backgroundColor: _splashBackground,
      body: Opacity(
        opacity: exitOpacity,
        child: ColoredBox(
          color: _splashBackground,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: MediaQuery.sizeOf(context).height * 0.22,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _splashAccent.withValues(alpha: glowOpacity),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isIOS ? 32 : 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      Opacity(
                        opacity: logoFade,
                        child: Transform.scale(
                          scale: logoScale,
                          child: const HeyCabyDriverLogo(
                            width: 260,
                            color: _splashAccent,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      _pillarLine(
                        opacity: pillar1Opacity,
                        slide: pillar1Slide,
                        text: copy.pillar1,
                        accentLast: false,
                      ),
                      SizedBox(height: isIOS ? 14 : 12),
                      _pillarLine(
                        opacity: pillar2Opacity,
                        slide: pillar2Slide,
                        text: copy.pillar2,
                        accentLast: false,
                      ),
                      SizedBox(height: isIOS ? 14 : 12),
                      _pillarLine(
                        opacity: pillar3Opacity,
                        slide: pillar3Slide,
                        text: copy.pillar3,
                        accentLast: false,
                      ),
                      SizedBox(height: isIOS ? 16 : 14),
                      _pillarLine(
                        opacity: pillar4Opacity,
                        slide: pillar4Slide,
                        text: copy.pillar4,
                        accentLast: true,
                      ),
                      const Spacer(),
                      if (canContinue)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onContinue,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _splashText,
                                  side: BorderSide(
                                    color: _splashText.withValues(alpha: 0.35),
                                  ),
                                  minimumSize: Size.fromHeight(buttonHeight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(radius),
                                  ),
                                ),
                                child: Text(
                                  copy.skipLabel,
                                  style: typography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _splashText,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isIOS ? 12 : 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: onContinue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _splashAccent,
                                  foregroundColor: _splashText,
                                  minimumSize: Size.fromHeight(buttonHeight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(radius),
                                  ),
                                ),
                                child: Text(
                                  copy.continueLabel,
                                  style: typography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _splashText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        DriverBrandMomentLoadingRow(
                          progress: loadingProgress,
                          isIOS: isIOS,
                        ),
                      const Spacer(flex: 2),
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

  Widget _pillarLine({
    required double opacity,
    required double slide,
    required String text,
    required bool accentLast,
  }) {
    const textColor = Color(0xFF111827);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, slide),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: typography.titleMedium.copyWith(
            color:
                accentLast ? _splashAccent : textColor.withValues(alpha: 0.92),
            height: 1.28,
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
            fontSize: accentLast ? 19.5 : 18,
          ),
        ),
      ),
    );
  }
}

/// Soft indeterminate feel without implying numeric progress.
class DriverBrandMomentLoadingRow extends StatelessWidget {
  const DriverBrandMomentLoadingRow({
    super.key,
    required this.progress,
    required this.isIOS,
  });

  final double progress;
  final bool isIOS;

  static const _accent = Color(0xFF00A651);
  static const _track = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: isIOS ? 3 : 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: _track.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (0.22 + 0.78 * ((progress * 1.15) % 1.0))
                      .clamp(0.15, 0.92),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE6F7EE), _accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LoadingDot(
                active: progress > 0.18 && progress < 0.45, isIOS: isIOS),
            SizedBox(width: isIOS ? 10 : 8),
            _LoadingDot(
                active: progress >= 0.40 && progress < 0.72, isIOS: isIOS),
            SizedBox(width: isIOS ? 10 : 8),
            _LoadingDot(active: progress >= 0.68, isIOS: isIOS),
          ],
        ),
      ],
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot({required this.active, required this.isIOS});

  final bool active;
  final bool isIOS;

  static const _accent = Color(0xFF00A651);
  static const _inactive = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: active ? (isIOS ? 22 : 18) : (isIOS ? 7 : 8),
      height: isIOS ? 7 : 8,
      decoration: BoxDecoration(
        color: active ? _accent : _inactive.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Default EN copy for golden previews.
const kDriverBrandMomentPreviewCopy = DriverBrandMomentCopy(
  pillar1: 'Set your own price',
  pillar2: 'Work when you want to',
  pillar3: 'Be your own boss, finally',
  pillar4: 'Commission-free',
  continueLabel: 'Continue',
  skipLabel: 'Skip',
);

/// NL copy map — mirrors splash screen locales.
const kDriverBrandMomentCopyByLanguage = <String, DriverBrandMomentCopy>{
  'en': kDriverBrandMomentPreviewCopy,
  'nl': DriverBrandMomentCopy(
    pillar1: 'Bepaal je eigen prijs',
    pillar2: 'Werk wanneer jij wilt',
    pillar3: 'Eindelijk je eigen baas',
    pillar4: 'Zonder commissie',
    continueLabel: 'Doorgaan',
    skipLabel: 'Overslaan',
  ),
};
