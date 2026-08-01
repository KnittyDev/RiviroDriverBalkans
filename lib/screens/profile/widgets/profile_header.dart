import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  final String name;

  const ProfileHeader({
    super.key,
    this.name = 'David!',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Driver Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primarySubtle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: const ClipOval(
            child: Icon(
              Icons.person_rounded,
              size: 30,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Greeting & Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
