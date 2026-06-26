import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_status_badge.dart';
import 'package:heycaby_driver/widgets/driver_app_suggestion_body.dart';
import 'package:heycaby_driver/widgets/driver_go_live_body.dart';
import 'package:heycaby_driver/widgets/driver_referral_share_body.dart';
import 'package:heycaby_driver/widgets/driver_ride_swap_body.dart';
import 'package:heycaby_driver/widgets/driver_work_flow_common.dart';

class DriverRideSwapPreview extends StatelessWidget {
  const DriverRideSwapPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _items = [
    DriverRideSwapOfferItem(
      urgencyLabel: 'Urgent',
      expiresLabel: 'Expires in 18 min',
      pickupAddress: '📍 Stationplein 1, Rotterdam',
      destinationAddress: 'Schiphol Airport',
      scheduleLabel: '🕐 Ophalen 16:30 · 58.2 km · 45 min',
      paymentLabel: '💵 cash / card',
      distanceLabel: '📍 2.4 km from you',
      urgencyTone: DriverStatusTone.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverRideSwapBody(
      colors: colors,
      typography: typography,
      onBack: () {},
      onRefresh: () async {},
      onShowInfo: () {},
      feed: DriverRideSwapFeedPreview(
        colors: colors,
        typography: typography,
        items: _items,
      ),
    );
  }
}

class DriverGoLivePreview extends StatelessWidget {
  const DriverGoLivePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverGoLiveBody(
      colors: colors,
      typography: typography,
      loading: false,
      onBack: () {},
      onGoOnline: () {},
      onBreak: () {},
      onOffline: () {},
    );
  }
}

class DriverReferralSharePreview extends StatelessWidget {
  const DriverReferralSharePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverReferralShareBody(
      colors: colors,
      typography: typography,
      loading: false,
      errorMessage: null,
      headline: 'Invite fellow drivers to HeyCaby',
      bullet: 'Share your link — when they join, you both benefit from a stronger driver network.',
      showLinkUnavailable: false,
      linkUnavailableTitle: '',
      linkUnavailableHint: '',
      inviteLinkLabel: 'Your invite link',
      shareUrl: 'https://heycaby.nl/drivers/join',
      shareLabel: 'Share link',
      copyLabel: 'Copy link',
      onBack: () {},
      onShare: () {},
      onCopy: () {},
    );
  }
}

class DriverAppSuggestionPreview extends StatefulWidget {
  const DriverAppSuggestionPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverAppSuggestionPreview> createState() =>
      _DriverAppSuggestionPreviewState();
}

class _DriverAppSuggestionPreviewState extends State<DriverAppSuggestionPreview> {
  late final TextEditingController _controller;

  static const _ideas = [
    DriverSuggestionIdeaItem(
      text: 'Show estimated toll costs before accepting long highway rides.',
      statusLabel: 'Planned',
      statusTone: DriverStatusTone.busy,
      votesLabel: '24 votes',
    ),
    DriverSuggestionIdeaItem(
      text: 'Break reminder when online for more than 4 hours.',
      statusLabel: 'Reviewing',
      statusTone: DriverStatusTone.warning,
      votesLabel: '11 votes',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverAppSuggestionBody(
      colors: widget.colors,
      typography: widget.typography,
      introText:
          'Tell us what features you want to see on the app.\n\n'
          'Your voice directly shapes what we build next.',
      hintText: DriverStrings.berichtTypen,
      controller: _controller,
      submitting: false,
      ideasLoading: false,
      ideasError: null,
      ideas: _ideas,
      onBack: () {},
      onSubmit: () {},
    );
  }
}
