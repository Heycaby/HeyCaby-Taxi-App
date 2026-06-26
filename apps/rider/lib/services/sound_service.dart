import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound service for playing audio in the rider app.
///
/// Sound assets are organized under:
/// - assets/sounds/rider/
/// - assets/sounds/driver/
/// - assets/sounds/shared/
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal() {
    _player.setPlayerMode(PlayerMode.lowLatency);
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(1.0);
  }

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Driver accepted the ride — plays once.
  Future<void> playDriverFound() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/driver_found.mp3');
  }

  /// Driver has arrived at pickup — plays once.
  Future<void> playDriverArrived() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/driver_arrived.mp3');
  }

  /// Booking request created (rider tapped "Find my driver") — plays once.
  Future<void> playBookingCreated() async {
    if (!_enabled) return;
    await _playRideSearchStarted();
  }

  /// Ride cancelled (by rider or system timeout) — plays once.
  Future<void> playRideCancelled() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/rider_cancelled.mp3');
  }

  /// Driver cancelled or request ended unexpectedly.
  Future<void> playDriverCancelled() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/driver_cancelled.mp3');
  }

  /// Driver ping — on the way to pickup (distinct from general notification).
  Future<void> playDriverPingOnMyWay() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/driver_found.mp3');
  }

  /// Driver ping — waiting outside pickup.
  Future<void> playDriverPingOutside() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/driver_arrived.mp3');
  }

  /// Incoming chat message or general notification — plays once.
  Future<void> playNotification() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/general_notification.mp3');
  }

  /// Trip completed — plays once.
  Future<void> playTripComplete() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/trip_complete.mp3');
  }

  /// Payment success / money confirmation sound for rider only.
  Future<void> playPaymentSuccess() async {
    if (!_enabled) return;
    await _playSound('sounds/rider/payment_success.mp3');
  }

  Future<void> _playRideSearchStarted() async {
    await _playSound('sounds/shared/general_notification.mp3');
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: Failed to play $assetPath - $e');
      }
      // Missing sound should be silent by design.
    }
  }

  /// Optional phishing/security warning sound.
  Future<void> playPhishingWarning() async {
    if (!_enabled) return;
    await _playSound('sounds/shared/general_notification.mp3');
  }

  void dispose() {
    _player.dispose();
  }
}
