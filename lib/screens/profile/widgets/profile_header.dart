import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_theme.dart';
import '../../settings/settings_screen.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final VoidCallback? onSettingsTap;

  const ProfileHeader({
    super.key,
    this.name = 'David!',
    this.onSettingsTap,
  });

  void _openSettings(BuildContext context) {
    if (onSettingsTap != null) {
      onSettingsTap!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Driver Avatar (Tapping avatar opens Settings or photo picker)
        ProfileService.buildAvatarWidget(
          size: 48,
          onTap: () => _openSettings(context),
        ),
        const SizedBox(width: 12),
        // Greeting & Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),

        // Settings Icon Button (Tapping settings icon opens Settings!)
        GestureDetector(
          onTap: () => _openSettings(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: AppColors.textDark,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
