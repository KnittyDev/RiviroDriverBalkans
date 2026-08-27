import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/driver_stats_service.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_reviews_modal.dart';
import '../../widgets/withdraw_modal.dart';
import 'widgets/profile_header.dart';
import 'widgets/balance_card.dart';
import 'widgets/stats_grid.dart';
import 'widgets/daily_income_chart.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _recentReviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllDriverData();
  }

  Future<void> _loadAllDriverData() async {
    final driverId = AuthService.currentDriverNotifier.value?.id;
    await DriverStatsService.fetchDriverLiveStats(driverId);
    
    if (driverId != null && driverId.isNotEmpty) {
      final list = await ReviewService.fetchDriverReviewsList(driverId);
      if (mounted) {
        setState(() {
          _recentReviews = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openReviewsModal() {
    final driverId = AuthService.currentDriverNotifier.value?.id;
    DriverReviewsModal.show(context, driverId: driverId);
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic safe bottom inset to guarantee zero overlap with floating navbar
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<DriverStatsModel>(
          valueListenable: DriverStatsService.statsNotifier,
          builder: (context, stats, child) {
            final balanceStr = '${stats.totalBalance.toStringAsFixed(2)}€';
            final ratingStr = stats.rating.toStringAsFixed(1);
            final tripsStr = '${stats.tripsToday}';
            final carStr = stats.carModel;
            final earnedTodayStr = '+${stats.earningsToday.toStringAsFixed(2)}€';

            return RefreshIndicator(
              onRefresh: _loadAllDriverData,
              color: AppColors.textDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                      balance: balanceStr,
                      onCashOutTap: () {
                        WithdrawModal.show(context, availableBalance: balanceStr);
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Bento Grid (Live Rating - Tappable, Trips today, Your car, Earned today)
                    StatsGrid(
                      rating: ratingStr,
                      tripsToday: tripsStr,
                      carModel: carStr,
                      carPlate: stats.carPlate,
                      tipsToday: earnedTodayStr,
                      tipsLabel: 'Earned today',
                      onRatingTap: _openReviewsModal,
                    ),
                    const SizedBox(height: 14),

                    // 4. Passenger Reviews Card
                    _buildReviewsPreviewCard(stats),
                    const SizedBox(height: 14),

                    // 5. Daily Income Chart Card
                    const DailyIncomeChart(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReviewsPreviewCard(DriverStatsModel stats) {
    final hasReviews = _recentReviews.isNotEmpty;
    final latestReview = hasReviews ? _recentReviews.first : null;
    final latestComment = latestReview?['comment']?.toString();
    final latestPassenger = latestReview?['passenger_name']?.toString() ?? 'Passenger';
    final latestPassengerAvatar = latestReview?['passenger_avatar_url']?.toString();

    return GestureDetector(
      onTap: _openReviewsModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryActiveBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passenger Reviews',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${stats.rating.toStringAsFixed(1)} Rating • ${_recentReviews.length} feedback${_recentReviews.length == 1 ? '' : 's'}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.textDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (latestReview != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySubtle,
                      ),
                      child: ClipOval(
                        child: (latestPassengerAvatar != null && latestPassengerAvatar.isNotEmpty)
                            ? Image.network(
                                latestPassengerAvatar,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: AppColors.textDark,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: AppColors.textDark,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                latestPassenger,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i) {
                                  final r = (latestReview['rating'] as num?)?.toDouble() ?? 5.0;
                                  return Icon(
                                    (i + 1) <= r.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 12,
                                    color: const Color(0xFFF59E0B),
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (latestComment != null && latestComment.trim().isNotEmpty)
                                ? '"${latestComment.trim()}"'
                                : 'Left 5-star trip feedback',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                              fontStyle: (latestComment != null && latestComment.trim().isNotEmpty)
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
