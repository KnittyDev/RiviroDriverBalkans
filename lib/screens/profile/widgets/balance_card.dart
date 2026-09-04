import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/driver_stats_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settle_debt_modal.dart';
import '../../../widgets/withdraw_history_modal.dart';

class BalanceCard extends StatelessWidget {
  final String balance;
  final VoidCallback? onCashOutTap;
  final VoidCallback? onSettleTap;

  const BalanceCard({
    super.key,
    this.balance = '0.00€',
    this.onCashOutTap,
    this.onSettleTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse numeric balance
    final cleanStr = balance
        .replaceAll('€', '')
        .replaceAll('Lek', '')
        .replaceAll('den', '')
        .replaceAll('MKD', '')
        .replaceAll('RSD', '')
        .replaceAll('+', '')
        .trim();
    final double numBalance = double.tryParse(cleanStr) ?? 0.0;
    final bool isNegative = numBalance < 0.0 || balance.trim().startsWith('-');

    return ValueListenableBuilder<double>(
      valueListenable: DriverStatsService.debtLimitNotifier,
      builder: (context, debtLimit, child) {
        final bool isLimitReached = numBalance <= debtLimit;
        final stats = DriverStatsService.statsNotifier.value;
        final String limitLabel = stats.formatCurrency(-debtLimit.abs());

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Label, Activity Button & Negative Limit Warning Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark.withValues(alpha: 0.75),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => WithdrawHistoryModal.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                size: 12,
                                color: AppColors.textDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Activity',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isNegative) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showBalanceExplanationModal(context, numBalance, debtLimit),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.textDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLimitReached ? Icons.warning_rounded : Icons.info_outline_rounded,
                                  size: 12,
                                  color: isLimitReached ? const Color(0xFFF59E0B) : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLimitReached ? 'Limit ($limitLabel)' : 'Limit: $limitLabel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isLimitReached ? const Color(0xFFF59E0B) : Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Main Balance Row & Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    balance,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: isNegative
                        ? onSettleTap ?? () => SettleDebtModal.show(context, currentDebt: numBalance)
                        : onCashOutTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textDark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isNegative ? 'Settle' : 'Withdraw',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Warning & "More Info" Strip
              if (isNegative) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showBalanceExplanationModal(context, numBalance, debtLimit),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: AppColors.textDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.textDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isLimitReached
                                ? 'Max $limitLabel limit reached! Settle to accept cash rides.'
                                : 'Cash commission due • Max limit: $limitLabel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.textDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'More Info',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showBalanceExplanationModal(BuildContext context, double numBalance, double debtLimit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom + 18;
        final stats = DriverStatsService.statsNotifier.value;
        final limitAmount = debtLimit.abs().toStringAsFixed(2);
        final currentAmount = numBalance.abs().toStringAsFixed(2);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 14,
            bottom: safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'About Negative Balance',
                      style: GoogleFonts.poppins(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reassurance Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is completely normal! Your account is in good standing.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Explanation Items
              _buildExplanationItem(
                icon: Icons.payments_outlined,
                title: 'You Kept 100% of the Cash Fare',
                description:
                    'When passengers pay cash, you keep all of it in your pocket. The platform\'s small commission (${stats.formatCurrency(numBalance.abs())}) is recorded to your balance.',
              ),
              const SizedBox(height: 12),
              _buildExplanationItem(
                icon: Icons.local_taxi_rounded,
                title: 'Keep Taking Rides Freely',
                description:
                    'You are not blocked! You can freely continue accepting ride requests until reaching your maximum limit of ${stats.formatCurrency(-debtLimit.abs())}.',
              ),
              const SizedBox(height: 12),
              _buildExplanationItem(
                icon: Icons.sync_alt_rounded,
                title: 'Easy Ways to Settle',
                description:
                    'Your balance automatically balances itself when you complete online/card paid trips, or you can pay via card with Online Pay anytime.',
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Got it, Thanks',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        SettleDebtModal.show(context, currentDebt: numBalance);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textDark,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Settle Online',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExplanationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textDark, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
