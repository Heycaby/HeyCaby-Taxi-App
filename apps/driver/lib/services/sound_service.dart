import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound service for playing audio in the driver app
///
/// Sound structure:
/// - assets/sounds/driver/...
/// - assets/sounds/shared/...
class SoundService {
  static const String rideRequestRingtoneAsset =
      'sounds/driver/ride_request_incoming.wav';

  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal() {
    // Keep cues snappy and audible for status-preview taps.
    _player.setPlayerMode(PlayerMode.lowLatency);
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(1.0);
  }

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  int _rideRequestSession = 0;

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Plays incoming ride request ringtone for the active offer window.
  Future<void> playRideRequest({
    Duration duration = const Duration(seconds: 30),
  }) async {
    if (!_enabled) return;
    final session = ++_rideRequestSession;
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(rideRequestRingtoneAsset));
      await Future<void>.delayed(duration);
      if (session == _rideRequestSession) {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: Failed to play incoming ride - $e');
      }
      // Missing sound should be silent by design.
    }
  }

  /// Stops the ride request sound (call on accept/decline/expire).
  void stopRideRequest() {
    _rideRequestSession++;
    _player.stop();
  }

  /// Confirmation that the driver has accepted a ride — plays once.
  Future<void> playRideAccepted() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3');
  }

  Future<void> playDriverCancelled() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/driver_cancelled.mp3');
  }

  /// Rider cancelled during an active trip.
  Future<void> playRiderCancelled() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/rider_cancelled.mp3');
  }

  Future<void> playNewBidReceived() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3');
  }

  Future<void> playShiftAlert() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3');
  }

  Future<void> playNotification() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3');
  }

  Future<void> playTripComplete() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/trip_complete.mp3');
  }

  Future<void> playPaymentSuccess() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/trip_complete.mp3', volume: 0.95);
  }

  /// Status cue when driver goes online (money mindset).
  Future<void> playStatusOnline() async {
    if (!_enabled) return;
    // Punchy and rewarding when driver goes online.
    await _playSoundOnce('sounds/shared/trip_complete.mp3', volume: 1.0);
  }

  /// Status cue when driver switches to break.
  Future<void> playStatusOnBreak() async {
    if (!_enabled) return;
    // Quieter, short transition cue for break mode.
    await _playSoundOnce('sounds/shared/driver_found.mp3', volume: 0.38);
  }

  /// Status cue when driver goes offline / ends shift.
  Future<void> playStatusOffline() async {
    if (!_enabled) return;
    // Clear end-of-shift cue, softer than online.
    await _playSoundOnce('sounds/shared/driver_cancelled.mp3', volume: 0.65);
  }

  /// Feedback cue when an action is blocked (e.g. cannot go online yet).
  Future<void> playActionBlocked() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3',
        volume: 0.42);
  }

  /// Premium short cue for quick tariff switching interactions.
  Future<void> playTariffSwitch() async {
    if (!_enabled) return;
    // Faint, short droplet cue so preference toggles stay subtle.
    await _playSoundOnce('sounds/shared/toggle_drop_soft.wav', volume: 0.24);
  }

  Future<void> _playSoundOnce(String assetPath, {double volume = 0.8}) async {
    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.stop();
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: Failed to play $assetPath - $e');
      }
      // Missing sound should be silent by design.
    }
  }

  Future<void> playPhishingWarning() async {
    if (!_enabled) return;
    await _playSoundOnce('sounds/shared/general_notification.mp3');
  }

  void stopAll() {
    _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
