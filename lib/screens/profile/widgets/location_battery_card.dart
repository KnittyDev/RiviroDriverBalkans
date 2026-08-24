import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/location_service.dart';
import '../../../services/battery_optimization_service.dart';
import '../../../services/supabase_location_tracker_service.dart';
import '../../../theme/app_theme.dart';

class LocationBatteryCard extends StatefulWidget {
  const LocationBatteryCard({super.key});

  @override
  State<LocationBatteryCard> createState() => _LocationBatteryCardState();
}

class _LocationBatteryCardState extends State<LocationBatteryCard> {
  LatLng? _currentGps;
  bool _isLoadingGps = false;
  bool _isBackgroundLocationGranted = false;
  bool _isBatteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetchGps();
  }

  Future<void> _checkPermissionsAndFetchGps() async {
    setState(() {
      _isLoadingGps = true;
    });

    // 1. Check background location status
    final bgStatus = await Permission.locationAlways.status;
    // 2. Check battery optimization status
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    // 3. Fetch current live GPS position
    final location = await LocationService.getCurrentLocation();

    if (mounted) {
      setState(() {
        _isBackgroundLocationGranted = bgStatus.isGranted;
        _isBatteryOptimizationIgnored = batteryStatus.isGranted;
        _currentGps = location ?? const LatLng(52.1673, 22.2902);
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _requestBackgroundLocation() async {
    // Request Always Location
    PermissionStatus status = await Permission.locationAlways.request();
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isGranted) {
        status = await Permission.locationAlways.request();
      }
    }

    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _isBackgroundLocationGranted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Background location permission granted! GPS active 24/7.',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } else {
      if (mounted) {
        _showExplanationDialog(
          title: 'Background Location Required',
          content:
              'Rivilo Driver needs "Allow all the time" location access so you can receive incoming ride offers even when the screen is locked or app is in the background.',
        );
      }
    }
  }

  Future<void> _requestDisableBatterySaver() async {
    BatteryOptimizationService.showBatterySaverModal(
      context,
      onGranted: () {
        if (mounted) {
          setState(() {
            _isBatteryOptimizationIgnored = true;
          });
        }
      },
    );
  }

  void _showBatteryOptimizationInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set Battery to Unrestricted',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To ensure Android does not kill background location tracking during shifts, please set Battery usage to Unrestricted:',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepRow('1', 'Tap "Open App Settings" below.'),
                  const SizedBox(height: 6),
                  _buildStepRow('2', 'Select "Battery" or "App Battery Usage".'),
                  const SizedBox(height: 6),
                  _buildStepRow('3', 'Choose "Unrestricted" (or Don\'t Optimize).'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isBatteryOptimizationIgnored = true;
              });
            },
            child: Text('Already Set', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Open App Settings',
              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textDark, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showExplanationDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'App Settings',
              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latStr = _currentGps != null ? _currentGps!.latitude.toStringAsFixed(5) : '52.16730';
    final lngStr = _currentGps != null ? _currentGps!.longitude.toStringAsFixed(5) : '22.29020';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Live GPS & Refresh Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location_rounded, color: AppColors.textDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Live Location & Battery',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _checkPermissionsAndFetchGps,
                icon: _isLoadingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Lat & Long Display Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LATITUDE',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        latStr,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LONGITUDE',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lngStr,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Live GPS',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Background Location & Battery Saver Permission Action Buttons
          Row(
            children: [
              // 1. Background Location Permission Button
              Expanded(
                child: GestureDetector(
                  onTap: _requestBackgroundLocation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isBackgroundLocationGranted
                          ? const Color(0xFF22C55E).withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isBackgroundLocationGranted
                            ? const Color(0xFF22C55E).withOpacity(0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isBackgroundLocationGranted
                                  ? Icons.check_circle_rounded
                                  : Icons.location_searching_rounded,
                              size: 14,
                              color: _isBackgroundLocationGranted
                                  ? const Color(0xFF15803D)
                                  : AppColors.textDark,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Background GPS',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isBackgroundLocationGranted ? 'Always Active 🟢' : 'Tap to Allow 24/7',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: _isBackgroundLocationGranted
                                ? const Color(0xFF15803D)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Battery Saver Optimization Disable Button
              Expanded(
                child: GestureDetector(
                  onTap: _requestDisableBatterySaver,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isBatteryOptimizationIgnored
                          ? const Color(0xFF22C55E).withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isBatteryOptimizationIgnored
                            ? const Color(0xFF22C55E).withOpacity(0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isBatteryOptimizationIgnored
                                  ? Icons.bolt_rounded
                                  : Icons.battery_saver_rounded,
                              size: 14,
                              color: _isBatteryOptimizationIgnored
                                  ? const Color(0xFF15803D)
                                  : AppColors.textDark,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Power Saver',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isBatteryOptimizationIgnored ? 'Unrestricted ⚡' : 'Tap to Disable Saver',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: _isBatteryOptimizationIgnored
                                ? const Color(0xFF15803D)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Supabase DB 50m Optimization Info Banner
          ValueListenableBuilder<String>(
            valueListenable: SupabaseLocationTrackerService().statusNotifier,
            builder: (context, statusText, child) {
              return ValueListenableBuilder<int>(
                valueListenable: SupabaseLocationTrackerService().totalSkippedCountNotifier,
                builder: (context, skippedCount, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, size: 14, color: AppColors.textDark),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Supabase 50m Sync: $statusText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (skippedCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${skippedCount} DB calls saved! ⚡',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
