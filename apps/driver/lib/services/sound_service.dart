import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound service for playing audio in the driver app
/// 
/// Sound structure:
/// - assets/sounds/driver/ride_request.mp3     → New ride request (repeating)
/// - assets/sounds/shared/notification.mp3     → Chat, updates
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

  /// Plays incoming ride request (loops until stopped).
  Future<void> playRideRequest() async {
    if (!_enabled) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/driver/ride_request.mp3'));
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService: playRideRequest - $e');
    }
  }

  /// Stops the ride request sound (call on accept/decline/expire).
  void stopRideRequest() {
    _player.stop();
  }

  /// Confirmation that the driver has accepted a ride — plays once.
  Future<void> playRideAccepted() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/notification.mp3');
  }

  Future<void> playNotification() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/notification.mp3');
  }

  Future<void> playTripComplete() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/trip_complete.mp3');
  }

  Future<void> _playSoundOnce(String assetPath) async {
    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: Failed to play $assetPath - $e');
      }
    }
  }

  void stopAll() {
    _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
