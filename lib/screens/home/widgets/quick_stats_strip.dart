import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class QuickStatsStrip extends StatelessWidget {
  final String todayEarnings;
  final String todayTrips;
  final String onlineTime;

  const QuickStatsStrip({
    super.key,
    this.todayEarnings = '124.50€',
    this.todayTrips = '8 Trips',
    this.onlineTime = '4h 12m',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Today's Earnings
        Expanded(
          child: _StatCard(
            title: 'Earnings',
            value: todayEarnings,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(width: 10),
        // 2. Trips Count
        Expanded(
          child: _StatCard(
            title: 'Completed',
            value: todayTrips,
            icon: Icons.directions_car_rounded,
          ),
        ),
        const SizedBox(width: 10),
        // 3. Online Time
        Expanded(
          child: _StatCard(
            title: 'Online',
            value: onlineTime,
            icon: Icons.timer_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
