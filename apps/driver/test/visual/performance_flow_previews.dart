import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_performance_flow_common.dart';
import 'package:heycaby_driver/widgets/driver_performance_scorecard_body.dart';
import 'package:heycaby_driver/widgets/driver_rate_control_body.dart';
import 'package:heycaby_driver/services/driver_data_service.dart';

import 'golden_text_theme.dart';

class DriverPerformanceScorecardPreview extends StatelessWidget {
  const DriverPerformanceScorecardPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _breakdown = [
    DriverScoreBreakdownItem(label: 'Punctuality', value: 4.6),
    DriverScoreBreakdownItem(label: 'Cleanliness', value: 4.8),
    DriverScoreBreakdownItem(label: 'Attitude', value: 4.9),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverPerformanceScorecardBody(
      colors: colors,
      typography: typography,
      loading: false,
      starsLabel: '4.8 ★',
      scorePercent: 96,
      ratingsCountLabel: '124 ${DriverStrings.ratingsInScore}',
      trustScore: 92,
      showNewDriverShield: false,
      showReviewFlag: false,
      reviewFlagBody: '',
      badges: const ['Top driver'],
      acceptanceRateLabel: '${DriverStrings.acceptanceRate}: 94%',
      breakdown: _breakdown,
      comments: const [],
      onBack: () {},
    );
  }
}

class DriverRateControlPreview extends StatelessWidget {
  const DriverRateControlPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final tokenColors = colors.tokens;
    final tokenTypo = buildDriverGoldenTypography();
    const profile = DriverRateProfile(
      id: 'preview-standard',
      driverId: 'preview-driver',
      profileName: 'Standaard',
      baseFare: 4.5,
      perKmRate: 2.2,
      perMinRate: 0.45,
      waitingRate: 0.35,
      isActive: true,
    );

    return DriverRateControlBody(
      colors: colors,
      typography: typography,
      tokenColors: tokenColors,
      tokenTypo: tokenTypo,
      loading: false,
      errorMessage: null,
      presetBanner: null,
      profiles: const [profile],
      selectedProfileId: profile.id,
      onProfileSelected: (_) {},
      baseFieldBuilder: (_) =>
          _MockField(label: DriverStrings.rateStart, value: '4.50'),
      kmFieldBuilder: (_) =>
          _MockField(label: DriverStrings.ratePerKm, value: '2.20'),
      minFieldBuilder: (_) =>
          _MockField(label: DriverStrings.ratePerMin, value: '0.45'),
      waitFieldBuilder: (_) =>
          _MockField(label: DriverStrings.rateWaiting, value: '0.35'),
      saving: false,
      onBack: () {},
      onSave: () {},
    );
  }
}

class _MockField extends StatelessWidget {
  const _MockField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class DriverDemandRadarPreview extends StatelessWidget {
  const DriverDemandRadarPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A2634),
      child: DriverDemandRadarOverlay(
        title: DriverStrings.hotspots,
        colors: colors,
        typography: typography,
        onBack: () {},
        onRefresh: () {},
        onRecenter: () {},
        bestZoneName: 'Amsterdam Centrum',
        bestZoneWaitingLabel: '12 riders waiting',
        bestZoneTierColor: colors.error,
        onBestZoneTap: () {},
      ),
    );
  }
}
