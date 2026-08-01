import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? json['description'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
    );
  }
}

class GooglePlacesService {
  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // 1. Fetch live autocomplete suggestions from Google Places API
  static Future<List<PlaceSuggestion>> fetchAutocomplete(String input) async {
    if (input.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List<dynamic>;
          return predictions.map((p) => PlaceSuggestion.fromJson(p)).toList();
        } else {
          debugPrint('Places API Status: ${data['status']} - ${data['error_message']}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching place suggestions: $e');
    }

    return [];
  }

  // 2. Fetch place details (LatLng coordinates) by placeId
  static Future<LatLng?> fetchPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,name,formatted_address&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final location = data['result']['geometry']['location'];
          final double lat = (location['lat'] as num).toDouble();
          final double lng = (location['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }

    return null;
  }

  // 3. Reverse Geocode coordinates to formatted street address
  static Future<String> reverseGeocode(double lat, double lng) async {
    // 1. Try Google Geocoding API first
    final googleUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey',
    );

    try {
      final response = await http.get(googleUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final String address = data['results'][0]['formatted_address'] ?? '';
          if (address.isNotEmpty) {
            final parts = address.split(',');
            if (parts.length >= 2) {
              return '${parts[0].trim()}, ${parts[1].trim()}';
            }
            return address;
          }
        }
      }
    } catch (e) {
      debugPrint('Google reverse geocode error: $e');
    }

    // 2. Fallback: OpenStreetMap Nominatim REST API
    try {
      final nomUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        nomUrl,
        headers: {'User-Agent': 'RiviloDriverApp/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressObj = data['address'] as Map<dynamic, dynamic>?;
        if (addressObj != null) {
          final road = addressObj['road'] ?? addressObj['pedestrian'] ?? addressObj['suburb'] ?? '';
          final houseNumber = addressObj['house_number'] ?? '';
          final city = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? '';

          if (road.isNotEmpty) {
            final streetPart = houseNumber.isNotEmpty ? '$road $houseNumber' : road;
            return city.isNotEmpty ? '$streetPart, $city' : streetPart;
          }
        }
        final String displayName = data['display_name'] ?? '';
        if (displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.length >= 2) {
            return '${parts[0].trim()}, ${parts[1].trim()}';
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode error: $e');
    }

    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}
