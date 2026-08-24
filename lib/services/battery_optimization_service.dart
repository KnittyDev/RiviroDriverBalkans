import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

class BatteryOptimizationService {
  static bool _hasPromptedThisSession = false;
  static bool isBatteryPermissionGrantedOrDismissed = false;

  /// Checks and automatically prompts the Power Saver / Battery Optimization dialog as soon as the app starts up
  static Future<void> checkAndPromptBatteryOptimizationOnStartup(BuildContext context) async {
    if (_hasPromptedThisSession || isBatteryPermissionGrantedOrDismissed) return;

    // 1. Check if battery optimization is ALREADY ignored / granted
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      isBatteryPermissionGrantedOrDismissed = true;
      _hasPromptedThisSession = true;
      return;
    }

    _hasPromptedThisSession = true;

    // 2. Request native system permission
    final reqResult = await Permission.ignoreBatteryOptimizations.request();

    // 3. If user tapped "ALLOW / OKAY" on system popup, DO NOT SHOW custom instructions modal!
    if (reqResult.isGranted) {
      isBatteryPermissionGrantedOrDismissed = true;
      return;
    }

    // 4. ONLY show custom modal if system request was denied or requires manual app settings configuration
    if (context.mounted) {
      showBatterySaverModal(context);
    }
  }

  /// Displays the interactive Battery Optimization modal
  static void showBatterySaverModal(BuildContext context, {VoidCallback? onGranted}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Disable Power Saver',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rivilo Driver needs Unrestricted Battery Saver mode to keep background GPS tracking active and receive instant ride requests when your screen is locked.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepItem('1', 'Tap "Open App Settings" below.'),
                  const SizedBox(height: 8),
                  _buildStepItem('2', 'Select "Battery" or "Battery Usage".'),
                  const SizedBox(height: 8),
                  _buildStepItem('3', 'Choose "Unrestricted" (Don\'t Optimize).'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              isBatteryPermissionGrantedOrDismissed = true;
              Navigator.pop(dialogContext);
            },
            child: Text('Skip for Now', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12.5)),
          ),
          ElevatedButton(
            onPressed: () async {
              isBatteryPermissionGrantedOrDismissed = true;
              Navigator.pop(dialogContext);
              // Open app settings
              await openAppSettings();
              if (onGranted != null) {
                onGranted();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Open App Settings',
              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStepItem(String stepNum, String text) {
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
              stepNum,
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
}
