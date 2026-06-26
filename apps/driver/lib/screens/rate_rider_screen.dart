import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_feedback_loop_body.dart';

class RateRiderScreen extends ConsumerStatefulWidget {
  const RateRiderScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends ConsumerState<RateRiderScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _loading = false;
  static const int _maxCommentLength = 100;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars < 1) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.selectRatingPrompt)),
      );
      return;
    }
    HapticService.mediumTap();
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'ride_request_id': widget.rideId,
        'driver_rating_of_rider': _stars,
        'driver_rated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final comment = _commentController.text.trim();
      if (comment.isNotEmpty) {
        payload['rider_comment'] = comment;
      }
      await ref.read(driverApiProvider).rateRider(payload: payload);
      HapticService.success();
      ref.read(driverStateProvider.notifier).clearActiveRide();
      if (!mounted) return;
      context.go('/driver');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.thanksForRating)),
      );
    } catch (e) {
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DriverStrings.actionFailedPrefix} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() {
    HapticService.lightTap();
    ref.read(driverStateProvider.notifier).clearActiveRide();
    context.go('/driver');
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverFeedbackLoopBody(
      colors: colors,
      typography: typography,
      stars: _stars,
      commentController: _commentController,
      maxCommentLength: _maxCommentLength,
      loading: _loading,
      onStarSelected: (star) => setState(() => _stars = star),
      onSubmit: _submit,
      onSkip: _skip,
      onClose: _skip,
    );
  }
}
