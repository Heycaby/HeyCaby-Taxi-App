import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/rider_ride_chat_listener.dart';

/// Global ride-chat realtime wiring (active ride + chat routes are outside shell).
class RiderRideChatScope extends ConsumerWidget {
  const RiderRideChatScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        const RiderRideChatListener(),
      ],
    );
  }
}
