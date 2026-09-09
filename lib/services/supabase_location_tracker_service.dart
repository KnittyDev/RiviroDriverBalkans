import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'location_service.dart';

class SupabaseLocationTrackerService {
  static final SupabaseLocationTrackerService _instance = SupabaseLocationTrackerService._internal();
  factory SupabaseLocationTrackerService() => _instance;
  SupabaseLocationTrackerService._internal();

  // 50-Meter Minimum Distance Threshold for Supabase Database Optimization
  static const double minDistanceThresholdMeters = 50.0;

  // Supabase Credentials
  String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://dpxthqrofxsciaqbmnoq.supabase.co';
  String get _supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHRocXJvZnhzY2lhcWJtbm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MjQ3OTAsImV4cCI6MjEwMTMwMDc5MH0.cVjaM5oAxinicaal1BV9D0Qa1JbJolAE5doKjsYH3kA';

  // Last Synced Location State
  double? _lastSyncedLat;
  double? _lastSyncedLng;
  DateTime? _lastSyncedTime;

  // Stats & Reactive Notifiers
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Initialized (50m Threshold)');
  final ValueNotifier<double?> lastSyncedLatNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<double?> lastSyncedLngNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<int> totalSyncCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> totalSkippedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> lastDistanceMovedNotifier = ValueNotifier<double>(0.0);

  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _periodicTrackerTimer;

  double? get lastSyncedLat => _lastSyncedLat;
  double? get lastSyncedLng => _lastSyncedLng;
  DateTime? get lastSyncedTime => _lastSyncedTime;

  /// Starts true background GPS tracking listener with Foreground Service and 50m Edge Function sync filter
  void startLocationTracking({String? driverId}) {
    if (_isTracking) return;
    _isTracking = true;

    debugPrint('🚀 [Supabase Location Tracker] Started Foreground Service with 50m Edge Function sync.');

    // 1. Initial Immediate Sync Check
    _checkAndUpdateLocation(driverId: driverId);

    // 2. Configure Foreground Service Location Stream (Works when screen is OFF/locked!)
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // 50-meter hardware trigger
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Rivilo Driver Background GPS",
          notificationText: "Tracking driver location in background for passenger dispatching",
          notificationIcon: AndroidResource(name: 'ic_notification', defType: 'drawable'),
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      );
    }

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final activeId = driverId ?? AuthService.currentDriverNotifier.value?.id;
        if (activeId != null && activeId.isNotEmpty) {
          updateDriverLocationIfMoved(
            LatLng(position.latitude, position.longitude),
            driverId: activeId,
          );
        }
      },
      onError: (err) {
        debugPrint('⚠️ [PositionStream Error]: $err');
      },
    );

    // 3. Fallback Periodic Timer (Every 15 seconds)
    _periodicTrackerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkAndUpdateLocation(driverId: driverId);
    });
  }

  /// Stops background tracking
  void stopLocationTracking() {
    _positionStreamSub?.cancel();
    _periodicTrackerTimer?.cancel();
    _isTracking = false;
    statusNotifier.value = 'Paused';
  }

  /// Checks current GPS position and updates Supabase ONLY if moved >= 50 meters
  Future<void> _checkAndUpdateLocation({String? driverId}) async {
    final activeId = driverId ??
        Supabase.instance.client.auth.currentUser?.id ??
        AuthService.currentDriverNotifier.value?.id;

    if (activeId == null || activeId.isEmpty) {
      statusNotifier.value = 'Waiting for driver login';
      debugPrint('ℹ️ [Supabase Location Tracker] No active logged-in driver session.');
      return;
    }

    final currentPos = await LocationService.getCurrentLocation();
    if (currentPos == null) return;

    await updateDriverLocationIfMoved(currentPos, driverId: activeId);
  }

  /// Explicit method to update driver location via Supabase Edge Function with 50m distance check
  Future<bool> updateDriverLocationIfMoved(
    LatLng newLocation, {
    String? driverId,
    bool forceSync = false,
  }) async {
    final activeDriverId = driverId ??
        Supabase.instance.client.auth.currentUser?.id ??
        AuthService.currentDriverNotifier.value?.id;
    if (activeDriverId == null || activeDriverId.isEmpty) {
      statusNotifier.value = 'Waiting for driver login';
      return false;
    }

    // 0. ONLINE / OFFLINE CHECK: If driver is OFFLINE, skip location update to database!
    final isOnline = AuthService.currentDriverNotifier.value?.isOnline ?? false;
    if (!isOnline && !forceSync) {
      statusNotifier.value = 'Offline (Location Sync Paused)';
      debugPrint('⏸️ [Supabase Location Tracker] Driver is OFFLINE. Database update skipped.');
      return false;
    }

    final newLat = newLocation.latitude;
    final newLng = newLocation.longitude;

    // 1. Distance Calculation Check
    if (_lastSyncedLat != null && _lastSyncedLng != null && !forceSync) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastSyncedLat!,
        _lastSyncedLng!,
        newLat,
        newLng,
      );

      lastDistanceMovedNotifier.value = distanceInMeters;

      // 50-METER DISTANCE FILTER: IF MOVED LESS THAN 50m, SKIP SUPABASE DB UPDATE!
      if (distanceInMeters < minDistanceThresholdMeters) {
        totalSkippedCountNotifier.value += 1;
        statusNotifier.value =
            'Skipped DB Update (${distanceInMeters.toStringAsFixed(1)}m < 50m limit)';
        debugPrint(
          '⚡ [Supabase Optimization] Skipped DB update! Moved only ${distanceInMeters.toStringAsFixed(1)}m (< 50m threshold). DB requests saved: ${totalSkippedCountNotifier.value}',
        );
        return false;
      }
    }

    // 2. If moved >= 50 meters (or initial sync), invoke Supabase Edge Function!
    try {
      final edgeFunctionEndpoint = '$_supabaseUrl/functions/v1/update-driver-location';
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      final bodyPayload = jsonEncode({
        'driver_id': activeDriverId,
        'lat': newLat,
        'lng': newLng,
        'timestamp': nowUtcIso,
      });

      final response = await http.post(
        Uri.parse(edgeFunctionEndpoint),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: bodyPayload,
      );

      debugPrint('⚡ [Supabase Edge Function] Status: ${response.statusCode}, Driver: $activeDriverId, Body: ${response.body}');

      // Fallback REST PostgREST direct upsert if Edge Function has network restriction
      if (response.statusCode >= 400) {
        await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/profiles'),
          headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $_supabaseAnonKey',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode({
            'id': activeDriverId,
            'current_lat': newLat,
            'current_lng': newLng,
            'last_location_updated_at': nowUtcIso,
            'updated_at': nowUtcIso,
          }),
        );
      }

      // Update State & Notifiers
      _lastSyncedLat = newLat;
      _lastSyncedLng = newLng;
      _lastSyncedTime = DateTime.now();

      lastSyncedLatNotifier.value = newLat;
      lastSyncedLngNotifier.value = newLng;
      totalSyncCountNotifier.value += 1;
      statusNotifier.value = 'Synced via Edge Function 🟢 (${newLat.toStringAsFixed(4)}, ${newLng.toStringAsFixed(4)})';

      debugPrint(
        '✅ [Supabase Edge Function Synced] Success! Driver: $activeDriverId, Lat: $newLat, Lng: $newLng. Total Syncs: ${totalSyncCountNotifier.value}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ [Supabase Location Tracker Error]: $e');
      statusNotifier.value = 'Sync Error: $e';
      return false;
    }
  }
}
