import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Debug information emitted during ride alert playback
class RideAlertDebugInfo {
  final int currentRepetition; // 1 to 5
  final int maxRepetitions; // 5
  final int elapsedMilliseconds; // e.g. 0, 2400, 4800...
  final int totalTimeoutSeconds; // 12
  final String audioAsset; // 'assets/sfx/ride.mp3'
  final double audioDurationSeconds; // 1.1s
  final String logMessage;

  RideAlertDebugInfo({
    required this.currentRepetition,
    required this.maxRepetitions,
    required this.elapsedMilliseconds,
    required this.totalTimeoutSeconds,
    required this.audioAsset,
    required this.audioDurationSeconds,
    required this.logMessage,
  });
}

class RideAlertService {
  static final RideAlertService _instance = RideAlertService._internal();
  factory RideAlertService() => _instance;
  RideAlertService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alertTimer;
  Stopwatch? _stopwatch;

  int _currentRepetition = 0;
  bool _isAlertActive = false;

  static const int maxRepetitions = 5; // 5 repetitions
  static const Duration intervalDuration = Duration(milliseconds: 2400); // 2.4s interval
  static const int timeoutSeconds = 12; // 12s total timeout

  final StreamController<RideAlertDebugInfo> _debugStreamController =
      StreamController<RideAlertDebugInfo>.broadcast();

  Stream<RideAlertDebugInfo> get debugStream => _debugStreamController.stream;
  bool get isAlertActive => _isAlertActive;

  /// Starts incoming ride alert with live debug tracking (12s timeout, 5 repetitions, 2.4s interval)
  Future<void> startRideAlert({
    VoidCallback? onTimeout,
  }) async {
    if (_isAlertActive) return;
    _isAlertActive = true;
    _currentRepetition = 0;
    _stopwatch = Stopwatch()..start();

    // Pulse #1 (0ms)
    _executePulse(1);

    // Schedule 2.4s interval repeats up to 5 times (12s max)
    _alertTimer = Timer.periodic(intervalDuration, (timer) {
      if (!_isAlertActive) {
        timer.cancel();
        return;
      }

      _currentRepetition++;

      if (_currentRepetition >= maxRepetitions) {
        final elapsed = _stopwatch?.elapsedMilliseconds ?? 12000;
        _emitDebugLog(
          rep: maxRepetitions,
          elapsedMs: elapsed,
          msg: '⏱️ Timeout reached: 5 repetitions completed at ${elapsed}ms (${(elapsed / 1000).toStringAsFixed(1)}s). Stopping alert.',
        );
        stopAlert();
        if (onTimeout != null) onTimeout();
      } else {
        _executePulse(_currentRepetition + 1);
      }
    });
  }

  /// Executes a single pulse with audio & vibration, logging exact ms timestamps
  Future<void> _executePulse(int repNumber) async {
    final elapsedMs = _stopwatch?.elapsedMilliseconds ?? 0;
    final elapsedSec = (elapsedMs / 1000).toStringAsFixed(2);

    final debugMsg =
        '🔊 Pulse #$repNumber/$maxRepetitions | Elapsed: ${elapsedMs}ms (${elapsedSec}s) | Audio: ride.mp3 (1.1s) | Haptics: Light pulse emitted';

    if (kDebugMode) {
      print('[RIDE_ALERT_DEBUG] $debugMsg');
    }

    _emitDebugLog(
      rep: repNumber,
      elapsedMs: elapsedMs,
      msg: debugMsg,
    );

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sfx/ride.mp3'));

      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(duration: 200); // Light vibration pulse on each repeat
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      HapticFeedback.lightImpact();
    }
  }

  void _emitDebugLog({
    required int rep,
    required int elapsedMs,
    required String msg,
  }) {
    if (!_debugStreamController.isClosed) {
      _debugStreamController.add(
        RideAlertDebugInfo(
          currentRepetition: rep,
          maxRepetitions: maxRepetitions,
          elapsedMilliseconds: elapsedMs,
          totalTimeoutSeconds: timeoutSeconds,
          audioAsset: 'assets/sfx/ride.mp3',
          audioDurationSeconds: 1.1,
          logMessage: msg,
        ),
      );
    }
  }

  /// Immediately stops alert and resets debug trackers
  Future<void> stopAlert() async {
    _isAlertActive = false;
    _currentRepetition = 0;
    _stopwatch?.stop();
    _stopwatch = null;
    _alertTimer?.cancel();
    _alertTimer = null;

    try {
      await _audioPlayer.stop();
      await Vibration.cancel();
    } catch (_) {}
  }
}
