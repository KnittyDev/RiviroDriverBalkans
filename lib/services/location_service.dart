import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

class LocationService {
  static final loc.Location _location = loc.Location();

  // Request location permissions & trigger in-app Google Play Services "Location Accuracy" Turn On system dialog
  static Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    bool justEnabled = false;
    loc.PermissionStatus permissionGranted;

    // 1. Check if GPS service is enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      // Triggers official native Google Play Services "Location Accuracy / Turn on" system dialog in-app!
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        debugPrint('Location service activation turned down by user.');
        return null;
      }
      justEnabled = true;
    }

    // 2. Check & request location permission
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        debugPrint('Location permission denied by user.');
        return null;
      }
      justEnabled = true;
    }

    if (permissionGranted == loc.PermissionStatus.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return null;
    }

    // If user just tapped "Turn On", wait briefly for Android GPS hardware initialization
    if (justEnabled) {
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    // 3. Fetch current live GPS position (with automatic retry if GPS hardware is initializing)
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final locData = await _location.getLocation().timeout(const Duration(seconds: 8));
        if (locData.latitude != null && locData.longitude != null) {
          return LatLng(locData.latitude!, locData.longitude!);
        }
      } catch (e) {
        debugPrint('Attempt $attempt error getting location data: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    return null;
  }

  // Alias helper method for initial permission request
  Future<bool> initAndRequestLocationPermission({bool forcePrompt = true}) async {
    final location = await getCurrentLocation();
    return location != null;
  }
}
