import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  /// Opens the external navigation app (Google Maps / Apple Maps) with turn-by-turn driving directions.
  /// Dynamically targets the passenger pickup or dropoff location depending on current trip phase.
  static Future<bool> openTurnByTurnNavigation({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final bool hasValidCoords = latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;

    final String? trimmedAddress = address?.trim();
    if (!hasValidCoords && (trimmedAddress == null || trimmedAddress.isEmpty)) {
      debugPrint('⚠️ [MapLauncherService] No valid coordinates or address provided.');
      return false;
    }

    final String coordDest = hasValidCoords ? '$latitude,$longitude' : Uri.encodeComponent(trimmedAddress!);

    try {
      if (kIsWeb) {
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$coordDest&travelmode=driving');
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

      if (Platform.isAndroid) {
        // 1. Android turn-by-turn navigation intent (Google Maps Navigation Mode)
        final androidNavUri = Uri.parse('google.navigation:q=$coordDest&mode=d');
        if (await canLaunchUrl(androidNavUri)) {
          debugPrint('🗺️ [MapLauncherService] Launching Android Google Maps navigation: $androidNavUri');
          return await launchUrl(androidNavUri, mode: LaunchMode.externalApplication);
        }

        // 2. Android geo URI fallback
        final geoUri = Uri.parse(
          hasValidCoords
              ? 'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(trimmedAddress ?? 'Destination')})'
              : 'geo:0,0?q=$coordDest',
        );
        if (await canLaunchUrl(geoUri)) {
          debugPrint('🗺️ [MapLauncherService] Launching geo URI: $geoUri');
          return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isIOS) {
        // 1. Check Google Maps on iOS if installed
        final googleMapsIosUri = Uri.parse('comgooglemaps://?daddr=$coordDest&directionsmode=driving');
        if (await canLaunchUrl(googleMapsIosUri)) {
          debugPrint('🗺️ [MapLauncherService] Launching Google Maps on iOS: $googleMapsIosUri');
          return await launchUrl(googleMapsIosUri, mode: LaunchMode.externalApplication);
        }

        // 2. Apple Maps turn-by-turn driving navigation (default on every iOS device)
        final appleMapsUri = Uri.parse('maps://?daddr=$coordDest&dirflg=d');
        if (await canLaunchUrl(appleMapsUri)) {
          debugPrint('🗺️ [MapLauncherService] Launching Apple Maps: $appleMapsUri');
          return await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        }

        // 3. Apple Maps web URL fallback
        final appleWebUri = Uri.parse('https://maps.apple.com/?daddr=$coordDest&dirflg=d');
        if (await canLaunchUrl(appleWebUri)) {
          debugPrint('🗺️ [MapLauncherService] Launching Apple Maps Web: $appleWebUri');
          return await launchUrl(appleWebUri, mode: LaunchMode.externalApplication);
        }
      }

      // Universal Google Maps web / app fallback
      final googleMapsWebUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$coordDest&travelmode=driving',
      );
      if (await canLaunchUrl(googleMapsWebUri)) {
        debugPrint('🗺️ [MapLauncherService] Launching Google Maps web fallback: $googleMapsWebUri');
        return await launchUrl(googleMapsWebUri, mode: LaunchMode.externalApplication);
      }

      return false;
    } catch (e) {
      debugPrint('❌ [MapLauncherService] Error launching map navigation: $e');
      return false;
    }
  }
}
