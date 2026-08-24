import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/withdraw_modal.dart';
import 'widgets/profile_header.dart';
import 'widgets/balance_card.dart';
import 'widgets/location_battery_card.dart';
import 'widgets/role_selector_card.dart';
import 'widgets/stats_grid.dart';
import 'widgets/daily_income_chart.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dynamic safe bottom inset to guarantee zero overlap with floating navbar
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Avatar, Hello [Driver Name], Settings icon)
              const ProfileHeader(),
              const SizedBox(height: 14),

              // 2. Balance Card with Integrated Withdraw Modal
              BalanceCard(
                balance: '1.245€',
                onCashOutTap: () {
                  WithdrawModal.show(context, availableBalance: '1.245€');
                },
              ),
              const SizedBox(height: 12),

              // 3. Live Location (Lat & Long) & Battery Saver Settings Card
              const LocationBatteryCard(),
              const SizedBox(height: 12),

              // 4. Role Selector Card (Driver, Rider, Admin)
              const RoleSelectorCard(),
              const SizedBox(height: 12),

              // 3. Bento Grid (Rating, Trips today, Your car, Tips today)
              const StatsGrid(
                rating: '4.8',
                tripsToday: '26',
                carModel: 'Hyundai Solaris, 1.6, 2020',
                tipsToday: '64€',
              ),
              const SizedBox(height: 12),

              // 4. Daily Income Chart Card
              const DailyIncomeChart(),
            ],
          ),
        ),
      ),
    );
  }
}
