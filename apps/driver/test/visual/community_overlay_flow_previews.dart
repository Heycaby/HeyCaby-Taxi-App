import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_community_create_post_body.dart';
import 'package:heycaby_driver/widgets/driver_community_overlay_bodies.dart';
import 'package:heycaby_driver/widgets/driver_staging_surface_body.dart';

class DriverCommunityNotificationsPreview extends StatelessWidget {
  const DriverCommunityNotificationsPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _items = [
    DriverCommunityNotificationPreviewItem(
      title: 'New announcement',
      body: 'Platform fee update for April — read the pinned post.',
      timeLabel: '12m ago',
      unread: true,
    ),
    DriverCommunityNotificationPreviewItem(
      title: 'Ride swap claimed',
      body: 'Your swap offer to Schiphol was accepted.',
      timeLabel: '2h ago',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background.withValues(alpha: 0.5),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DriverCommunityNotificationsSheetBody(
          colors: colors,
          typography: typography,
          loading: false,
          error: null,
          items: _items,
          onMarkAllRead: () {},
          onClearRead: () {},
          onNotificationTap: (_) {},
        ),
      ),
    );
  }
}

class DriverCommunitySearchPreview extends StatelessWidget {
  const DriverCommunitySearchPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _results = [
    DriverCommunitySearchPreviewItem(
      title: '[traffic] A13 closed near Delft',
      subtitle: 'Driver talk • 2026-05-19',
    ),
    DriverCommunitySearchPreviewItem(
      title: '[tip] Best hours near Centraal',
      subtitle: 'Driver talk • 2026-05-18',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background.withValues(alpha: 0.5),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DriverCommunitySearchSheetBody(
          colors: colors,
          typography: typography,
          previewResults: _results,
        ),
      ),
    );
  }
}

class DriverCommunityDisclaimerPreview extends StatelessWidget {
  const DriverCommunityDisclaimerPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.background.withValues(alpha: 0.4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          child: Material(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: DriverCommunityDisclaimerBody(
              colors: colors,
              typography: typography,
              checked: true,
              onCheckedChanged: (_) {},
              onContactSupport: () {},
              onJoin: () {},
            ),
          ),
        ),
      ),
    );
  }
}

class DriverCommunityCreatePostPreview extends StatefulWidget {
  const DriverCommunityCreatePostPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverCommunityCreatePostPreview> createState() =>
      _DriverCommunityCreatePostPreviewState();
}

class _DriverCommunityCreatePostPreviewState
    extends State<DriverCommunityCreatePostPreview> {
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    _message = TextEditingController(
      text: '[traffic] Slow lane on A20 near Maasdijk.',
    );
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.colors.background.withValues(alpha: 0.5),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DriverCommunityCreatePostBody(
          colors: widget.colors,
          typography: widget.typography,
          isPoll: false,
          postType: 'traffic',
          messageController: _message,
          pollQuestionController: TextEditingController(),
          pollOptionControllers: const [],
          onKindChanged: (_) {},
          onPostTypeChanged: (_) {},
          onAddPollOption: () {},
          onSubmit: () {},
        ),
      ),
    );
  }
}

class DriverStagingSurfacePreview extends StatelessWidget {
  const DriverStagingSurfacePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverStagingSurfaceBody(
      colors: colors,
      typography: typography,
      title: DriverStrings.community,
      icon: Icons.construction_rounded,
    );
  }
}
