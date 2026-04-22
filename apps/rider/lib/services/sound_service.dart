import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound service for playing audio in the rider app.
///
/// Sound assets:
/// - assets/sounds/rider/driver_found.mp3      → Driver accepted the ride
/// - assets/sounds/rider/driver_arrived.mp3    → Driver at pickup location
/// - assets/sounds/shared/notification.mp3     → Chat messages, general alerts
/// - assets/sounds/shared/trip_complete.mp3    → Ride finished
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Driver accepted the ride — plays once.
  Future<void> playDriverFound() async {
    if (!_enabled) return;
    await _playSound('sounds/rider/driver_found.mp3');
  }

  /// Driver has arrived at pickup — plays once.
  Future<void> playDriverArrived() async {
    if (!_enabled) return;
    await _playSound('sounds/rider/driver_arrived.mp3');
  }

  /// Booking request created (rider tapped "Find my driver") — plays once.
  Future<void> playBookingCreated() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/notification.mp3');
  }

  /// Ride cancelled (by rider or system timeout) — plays once.
  Future<void> playRideCancelled() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/notification.mp3');
  }

  /// Incoming chat message or general notification — plays once.
  Future<void> playNotification() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/notification.mp3');
  }

  /// Trip completed — plays once.
  Future<void> playTripComplete() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/trip_complete.mp3');
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: Failed to play $assetPath - $e');
      }
    }
  }

  void dispose() {
    _player.dispose();
  }
}
