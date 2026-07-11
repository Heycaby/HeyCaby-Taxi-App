import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/rating_route_args.dart';
import '../screens/rating_screen.dart';

/// Post-payment: thank-you beat, then compact driver rating (4–5★ → favourite).
Future<void> showPostPaymentThankYouThenRate(
  BuildContext context, {
  required RatingRouteArgs routeArgs,
}) {
  return showRateDriverSheet(
    context,
    routeArgs: routeArgs,
    showPaymentThankYouFirst: true,
  );
}

/// Post-payment driver rating presented as a modal sheet (matches pay-driver UX).
Future<void> showRateDriverSheet(
  BuildContext context, {
  required RatingRouteArgs routeArgs,
  bool showPaymentThankYouFirst = false,
}) {
  final colors =
      ProviderScope.containerOf(context, listen: false).read(colorsProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    isDismissible: false,
    enableDrag: false,
    builder: (_) => RatingScreen(
      routeArgs: routeArgs,
      presentation: RatingPresentation.modal,
      showPaymentThankYouFirst: showPaymentThankYouFirst,
    ),
  );
}
