import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Service responsible for managing high-attention driver ride request vibrations
/// following Google Play Store and Apple App Store Haptic Guidelines.
class RideVibrationService {
  static final RideVibrationService _instance = RideVibrationService._internal();
  factory RideVibrationService() => _instance;
  RideVibrationService._internal();

  Timer? _vibrationTimer;
  bool _isVibrating = false;

  bool get isVibrating => _isVibrating;

  /// Starts a prolonged attention-grabbing vibration pattern for incoming ride requests.
  /// Standard pattern: Vibrate 600ms -> Pause 200ms -> Vibrate 800ms -> Pause 200ms -> Repeat
  Future<void> startRideRequestVibration({int timeoutSeconds = 25}) async {
    if (_isVibrating) return;
    _isVibrating = true;

    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      final hasCustomSupport = await Vibration.hasCustomVibrationsSupport() ?? false;

      if (hasVibrator) {
        if (hasCustomSupport) {
          // Android / Devices supporting custom vibration patterns & intensities
          Vibration.vibrate(
            pattern: [0, 600, 200, 800, 200, 1000],
            intensities: [0, 255, 0, 255, 0, 255],
            repeat: 0, // Repeat pattern until stopped
          );
        } else {
          // iOS Taptic Engine / Fallback: Repeat periodic heavy haptic pulses
          _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
            HapticFeedback.heavyImpact();
            Vibration.vibrate(duration: 500);
          });
        }
      } else {
        // Basic fallback
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
          HapticFeedback.vibrate();
        });
      }
    } catch (_) {
      // Fallback to system haptics on error
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        HapticFeedback.heavyImpact();
      });
    }

    // Auto timeout to prevent infinite vibration & preserve battery (App Store & Play Store policy compliant)
    Future.delayed(Duration(seconds: timeoutSeconds), () {
      stopVibration();
    });
  }

  /// Immediately stops any ongoing ride request vibration.
  /// Should be called when driver accepts, declines, or screen is disposed.
  Future<void> stopVibration() async {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}
