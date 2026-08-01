import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsService {
  // Fetch real road navigation geometry following actual streets via OSRM Driving API
  static Future<List<LatLng>> fetchRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List<dynamic>;

          final List<LatLng> points = coordinates.map((coord) {
            final double lng = (coord[0] as num).toDouble();
            final double lat = (coord[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          return points;
        }
      }
    } catch (e) {
      debugPrint('Directions API error, fallback to intermediate points: $e');
    }

    // Fallback: If network is offline, generate a subtle L-shaped street path instead of a straight line
    return [
      start,
      LatLng(start.latitude, end.longitude),
      end,
    ];
  }
}
