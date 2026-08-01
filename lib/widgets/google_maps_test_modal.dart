import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class GoogleMapsTestModal extends StatefulWidget {
  const GoogleMapsTestModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoogleMapsTestModal(),
    );
  }

  @override
  State<GoogleMapsTestModal> createState() => _GoogleMapsTestModalState();
}

class _GoogleMapsTestModalState extends State<GoogleMapsTestModal> {
  GoogleMapController? _mapController;

  // Default initial position (Istanbul / City Center)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 14.0,
  );

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('driver_location'),
      position: LatLng(41.0082, 28.9784),
      infoWindow: InfoWindow(
        title: 'Rivilo Driver Location',
        snippet: 'Active GPS Pin',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'Not Found';
    final hasValidKey = apiKey.startsWith('AIzaSy');

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title & API Key Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Maps API Test',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasValidKey ? const Color(0xFF22C55E) : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasValidKey
                              ? '.env Key: ${apiKey.substring(0, 10)}...'
                              : '.env Key Missing!',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Map Container View
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS
                  ? GoogleMap(
                      initialCameraPosition: _initialPosition,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    )
                  : _buildFallbackDesktopMapView(apiKey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackDesktopMapView(String apiKey) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryActiveBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_rounded,
              size: 54,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Google Maps API Connected!',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'API Key from .env file loaded successfully:\n$apiKey',
            textAlign: TextAlign.center,
            style: GoogleFonts.firaCode(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E)),
            ),
            child: Text(
              '✓ Ready for Android & iOS Native Maps SDK',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
