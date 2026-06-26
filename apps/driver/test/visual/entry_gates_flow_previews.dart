import 'package:flutter/material.dart';
import 'package:heycaby_driver/models/driver_runtime_models.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_dynamic_checklist_card.dart';
import 'package:heycaby_driver/widgets/driver_entry_flow_common.dart';
import 'package:heycaby_driver/widgets/driver_knowledge_base_body.dart';
import 'package:heycaby_driver/widgets/driver_onboarding_gate_body.dart';
import 'package:heycaby_driver/widgets/driver_readiness_gate_body.dart';
import 'package:heycaby_driver/widgets/driver_update_gate_body.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class DriverOnboardingGatePreview extends StatefulWidget {
  const DriverOnboardingGatePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverOnboardingGatePreview> createState() =>
      _DriverOnboardingGatePreviewState();
}

class _DriverOnboardingGatePreviewState extends State<DriverOnboardingGatePreview> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: 'driver@example.com');
    _password = TextEditingController(text: '••••••••');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverOnboardingGateBody(
      colors: widget.colors,
      typography: widget.typography,
      compact: true,
      emailController: _email,
      passwordController: _password,
      loading: false,
      error: null,
      onBack: () {},
      onSubmit: () {},
    );
  }
}

class DriverKnowledgeBasePreview extends StatelessWidget {
  const DriverKnowledgeBasePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverKnowledgeBaseBody(
      colors: colors,
      typography: typography,
      onBack: () {},
      content: DriverKnowledgeBasePlaceholder(
        colors: colors,
        typography: typography,
      ),
    );
  }
}

class DriverReadinessGatePreview extends StatelessWidget {
  const DriverReadinessGatePreview({
    super.key,
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.themeTypo,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypo;

  static const _checklist = [
    DriverReadinessItem(
      key: 'identity',
      label: 'Verify your identity',
      complete: false,
      action: 'Open Veriff',
    ),
    DriverReadinessItem(
      key: 'vehicle',
      label: 'Add vehicle details',
      complete: true,
    ),
    DriverReadinessItem(
      key: 'billing',
      label: 'Activate platform subscription',
      complete: false,
      action: 'View billing',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverReadinessGateBody(
      colors: colors,
      typography: typography,
      title: 'Complete your profile before going online',
      body:
          'A few steps remain before you can accept rides. Finish the checklist below to unlock go-live.',
      checklist: DriverDynamicChecklistCard(
        items: _checklist,
        colors: themeColors,
        typo: themeTypo,
      ),
      primaryLabel: 'Continue setup',
      onPrimary: () {},
      secondaryLabel: 'View documents',
      onSecondary: () {},
      onBackHome: () {},
      onBack: () {},
    );
  }
}

class DriverUpdateGatePreview extends StatelessWidget {
  const DriverUpdateGatePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverUpdateGateBody(
      colors: colors,
      typography: typography,
      title: 'Please update iOS',
      body:
          'HeyCaby Driver requires iOS 18 or later. This iPhone is on iOS 17.4. '
          'Open Settings → General → Software Update to install the latest iOS your device supports.',
      footer: 'Minimum supported version: iOS 18',
    );
  }
}
