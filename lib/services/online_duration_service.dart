import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineDurationService {
  static const String _keyDate = 'driver_online_tracking_date';
  static const String _keyAccumulatedSeconds = 'driver_online_accumulated_seconds';
  static const String _keyStartTimestamp = 'driver_last_online_start_timestamp';

  static int _accumulatedSecondsToday = 0;
  static int _lastOnlineStartMs = 0; // 0 if currently offline
  static Timer? _tickerTimer;
  static bool _isInitialized = false;

  /// Reactive notifier for UI (e.g. '0m', '45m', '3h 12m')
  static final ValueNotifier<String> onlineTimeStringNotifier =
      ValueNotifier<String>('0m');

  /// Reactive notifier for total online seconds today
  static final ValueNotifier<int> totalSecondsTodayNotifier =
      ValueNotifier<int>(0);

  /// Initializes local online tracker, restores today's elapsed time and handles midnight reset
  static Future<void> init({bool isCurrentlyOnline = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayDateString();
      final storedDate = prefs.getString(_keyDate) ?? todayStr;

      if (storedDate != todayStr) {
        // New day has started! Reset daily accumulated time
        _accumulatedSecondsToday = 0;
        _lastOnlineStartMs = isCurrentlyOnline ? DateTime.now().millisecondsSinceEpoch : 0;
        await prefs.setString(_keyDate, todayStr);
        await prefs.setInt(_keyAccumulatedSeconds, 0);
        await prefs.setInt(_keyStartTimestamp, _lastOnlineStartMs);
      } else {
        _accumulatedSecondsToday = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
        _lastOnlineStartMs = prefs.getInt(_keyStartTimestamp) ?? 0;

        // If app says driver is online or prefs had active start timestamp
        if (isCurrentlyOnline && _lastOnlineStartMs == 0) {
          _lastOnlineStartMs = DateTime.now().millisecondsSinceEpoch;
          await prefs.setInt(_keyStartTimestamp, _lastOnlineStartMs);
        } else if (!isCurrentlyOnline && _lastOnlineStartMs > 0) {
          // Reconcile offline state
          final elapsed = (DateTime.now().millisecondsSinceEpoch - _lastOnlineStartMs) ~/ 1000;
          if (elapsed > 0) _accumulatedSecondsToday += elapsed;
          _lastOnlineStartMs = 0;
          await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSecondsToday);
          await prefs.setInt(_keyStartTimestamp, 0);
        }
      }

      _isInitialized = true;
      _updateTotalAndNotify();

      if (isCurrentlyOnline || _lastOnlineStartMs > 0) {
        _startTicker();
      }
    } catch (e) {
      debugPrint('⚠️ [OnlineDurationService] Init error: $e');
    }
  }

  /// Called whenever driver toggles Online / Offline
  static Future<void> onOnlineStatusChanged(bool isOnline) async {
    if (!_isInitialized) {
      await init(isCurrentlyOnline: isOnline);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndHandleMidnightRollover(prefs);

      if (isOnline) {
        if (_lastOnlineStartMs == 0) {
          _lastOnlineStartMs = DateTime.now().millisecondsSinceEpoch;
          await prefs.setInt(_keyStartTimestamp, _lastOnlineStartMs);
        }
        _startTicker();
      } else {
        if (_lastOnlineStartMs > 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final sessionSeconds = (now - _lastOnlineStartMs) ~/ 1000;
          if (sessionSeconds > 0) {
            _accumulatedSecondsToday += sessionSeconds;
          }
          _lastOnlineStartMs = 0;
          await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSecondsToday);
          await prefs.setInt(_keyStartTimestamp, 0);
        }
        _stopTicker();
      }

      _updateTotalAndNotify();
    } catch (e) {
      debugPrint('⚠️ [OnlineDurationService] onOnlineStatusChanged error: $e');
    }
  }

  /// Syncs current in-memory session to disk (e.g. app lifecycle paused / resumed)
  static Future<void> syncSession() async {
    if (!_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndHandleMidnightRollover(prefs);

      if (_lastOnlineStartMs > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final currentSessionSeconds = (now - _lastOnlineStartMs) ~/ 1000;
        final totalSoFar = _accumulatedSecondsToday + (currentSessionSeconds > 0 ? currentSessionSeconds : 0);
        await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSecondsToday);
        _updateTotalAndNotify();
        debugPrint('⏱️ [OnlineDurationService] Session synced: ${formatDuration(totalSoFar)}');
      } else {
        await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSecondsToday);
        _updateTotalAndNotify();
      }
    } catch (_) {}
  }

  static void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndHandleMidnightRollover(prefs);
      _updateTotalAndNotify();
    });
  }

  static void _stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  static void _updateTotalAndNotify() {
    int total = _accumulatedSecondsToday;
    if (_lastOnlineStartMs > 0) {
      final sessionSeconds = (DateTime.now().millisecondsSinceEpoch - _lastOnlineStartMs) ~/ 1000;
      if (sessionSeconds > 0) {
        total += sessionSeconds;
      }
    }

    totalSecondsTodayNotifier.value = total;
    onlineTimeStringNotifier.value = formatDuration(total);
  }

  static Future<void> _checkAndHandleMidnightRollover(SharedPreferences prefs) async {
    final todayStr = _getTodayDateString();
    final storedDate = prefs.getString(_keyDate);

    if (storedDate != null && storedDate != todayStr) {
      // Midnight has passed!
      _accumulatedSecondsToday = 0;
      if (_lastOnlineStartMs > 0) {
        _lastOnlineStartMs = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_keyStartTimestamp, _lastOnlineStartMs);
      }
      await prefs.setString(_keyDate, todayStr);
      await prefs.setInt(_keyAccumulatedSeconds, 0);
      debugPrint('🌙 [OnlineDurationService] Midnight reset triggered. New day: $todayStr');
    }
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Formats raw seconds to user-friendly string (e.g. '0m', '42m', '3h 15m')
  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours == 0) {
      return minutes > 0 ? '${minutes}m' : '0m';
    } else {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
}
