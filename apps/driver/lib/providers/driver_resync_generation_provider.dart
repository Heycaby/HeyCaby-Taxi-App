import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment to force Supabase realtime listeners to resubscribe (Program 3E).
class DriverResyncGenerationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final driverResyncGenerationProvider =
    NotifierProvider<DriverResyncGenerationNotifier, int>(
  DriverResyncGenerationNotifier.new,
);
