import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import '../../theme/app_theme.dart';
import '../../services/directions_service.dart';
import '../../services/location_service.dart';

class RideNavigationScreen extends StatefulWidget {
  final String passengerName;
  final String pickupAddress;
  final String dropoffAddress;

  const RideNavigationScreen({
    super.key,
    this.passengerName = 'Marcus Vance',
    this.pickupAddress = 'Current Driver Location',
    this.dropoffAddress = 'Galeria Siedlce, Poland',
  });

  @override
  State<RideNavigationScreen> createState() => _RideNavigationScreenState();
}

class _RideNavigationScreenState extends State<RideNavigationScreen> {
  GoogleMapController? _mapController;

  // Real Destination (Galeria Siedlce, Poland)
  static const LatLng _dropoffLatLng = LatLng(52.1691, 22.2798);

  // Driver Real Live GPS Coordinates
  LatLng _driverCurrentGps = const LatLng(52.1673, 22.2902);
  bool _isFetchingRealGps = true;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  // Custom Bitmap Markers
  BitmapDescriptor? _driverCarIcon;
  BitmapDescriptor? _destinationIcon;

  // Real Device GPS Stream Subscription
  final loc.Location _locationPlugin = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcons().then((_) {
      _setupRealDeviceGpsTracking();
    });
  }

  /// Generates custom high-resolution BitmapDescriptor icons matching custom Widget designs:
  /// 1. Driver: #99CFCF circle, white 2.5 border, car icon
  /// 2. Destination: #EF4444 red circle, white 2 border, location pin icon
  Future<void> _loadCustomMarkerIcons() async {
    try {
      _driverCarIcon = await _createDriverCarBitmap();
      _destinationIcon = await _createDestinationBitmap();
    } catch (e) {
      debugPrint('Error creating custom marker bitmaps: $e');
    }
  }

  Future<BitmapDescriptor> _createDriverCarBitmap() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(120, 120);

    final bgPaint = Paint()..color = AppColors.primary; // #99CFCF
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 50, bgPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 50, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.directions_car_rounded.codePoint),
      style: TextStyle(
        fontSize: 54,
        fontFamily: Icons.directions_car_rounded.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(120, 120);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createDestinationBitmap() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(100, 100);

    final bgPaint = Paint()..color = const Color(0xFFEF4444);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, bgPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on_rounded.codePoint),
      style: TextStyle(
        fontSize: 48,
        fontFamily: Icons.location_on_rounded.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(100, 100);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  /// Sets up 100% real device hardware GPS tracking & road route
  Future<void> _setupRealDeviceGpsTracking() async {
    try {
      final initialGps = await LocationService.getCurrentLocation();
      if (initialGps != null) {
        _driverCurrentGps = initialGps;
      }
    } catch (e) {
      debugPrint('Error getting real initial GPS location: $e');
    }

    if (mounted) {
      setState(() {
        _isFetchingRealGps = false;
      });
    }

    // Fetch real street road route from Driver's actual GPS to Destination
    _routePoints = await DirectionsService.fetchRoadRoute(_driverCurrentGps, _dropoffLatLng);

    if (_routePoints.length < 2) {
      _routePoints = [_driverCurrentGps, _dropoffLatLng];
    }

    if (mounted) {
      setState(() {
        _updateMarkers();

        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('real_device_gps_route'),
            points: _routePoints,
            color: AppColors.primary,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });

      _recenterMap();
    }

    // Listen to REAL hardware GPS sensor updates from smartphone
    try {
      await _locationPlugin.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 2.0,
      );

      _locationSubscription = _locationPlugin.onLocationChanged.listen((locData) {
        if (!mounted) return;

        if (locData.latitude != null && locData.longitude != null) {
          final realGpsPos = LatLng(locData.latitude!, locData.longitude!);
          final heading = locData.heading ?? 0.0;

          setState(() {
            _driverCurrentGps = realGpsPos;
            _updateMarkers();
          });

          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: realGpsPos,
                zoom: 17.0,
                bearing: heading,
                tilt: 45.0,
              ),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error starting real device GPS listener: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // 1. Custom Driver Vehicle Marker (#99CFCF Buz Turkuazı Daire + Beyaz Araba İkonu)
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_real_gps'),
        position: _driverCurrentGps,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(
          title: 'Your Real Device GPS',
          snippet: 'Driver Vehicle Location',
        ),
        icon: _driverCarIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // 2. Custom Destination Marker (#EF4444 Kırmızı Daire + Beyaz Konum İkonu)
    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(
          title: 'Destination',
          snippet: 'Galeria Siedlce, Poland',
        ),
        icon: _destinationIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driverCurrentGps,
          zoom: 17.0,
          tilt: 45.0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Maps Real Hardware Device GPS Navigation View
          defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverCurrentGps,
                    zoom: 16.5,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                )
              : _buildDesktopFallbackMapView(),

          // 2. Top Navigation Bar Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),

                  // Real GPS Tracking Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.textDark,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isFetchingRealGps
                              ? 'CONNECTING GPS SENSORS...'
                              : 'LIVE DEVICE GPS TRACKING',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recenter Button
                  GestureDetector(
                    onTap: _recenterMap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Turn-by-Turn Instruction Banner
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: AppColors.textDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real Device Navigation',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Destination: ${widget.dropoffAddress}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Navigation & Passenger Detail Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 24 + bottomInset,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route Timeline summary
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Real Hardware GPS Live Stream',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Real Device Position ➔ ${widget.dropoffAddress}',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Arrived / Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Arrived at ${widget.dropoffAddress}!',
                              style: GoogleFonts.poppins(fontSize: 12.5),
                            ),
                            backgroundColor: AppColors.textDark,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.textDark,
                      ),
                      label: Text(
                        'Arrived at Destination',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFallbackMapView() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gps_fixed_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Real Hardware Device GPS Mode',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tracking phone location via GPS sensors',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
