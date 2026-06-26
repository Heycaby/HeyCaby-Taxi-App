import 'dart:async';

/// Queues driver actions while offline; flushed on reconnect (Program 3E).
class DriverOfflineActionQueue {
  DriverOfflineActionQueue._();

  static final DriverOfflineActionQueue instance = DriverOfflineActionQueue._();

  final List<Future<void> Function()> _pending = [];
  bool _flushing = false;

  int get pendingCount => _pending.length;

  void enqueue(Future<void> Function() action) {
    _pending.add(action);
  }

  Future<void> flush() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    final batch = List<Future<void> Function()>.from(_pending);
    _pending.clear();
    for (final action in batch) {
      try {
        await action();
      } catch (_) {
        // Drop failed retries; user can retry manually.
      }
    }
    _flushing = false;
  }

  void clear() => _pending.clear();
}
