import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

class DriverReviewsModal extends StatefulWidget {
  final String? driverId;

  const DriverReviewsModal({super.key, this.driverId});

  static void show(BuildContext context, {String? driverId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverReviewsModal(driverId: driverId),
    );
  }

  @override
  State<DriverReviewsModal> createState() => _DriverReviewsModalState();
}

class _DriverReviewsModalState extends State<DriverReviewsModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 5.0;
  Map<int, int> _starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  Map<String, int> _tagCounts = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final effectiveDriverId = widget.driverId ??
        AuthService.currentDriverNotifier.value?.id;

    if (effectiveDriverId == null || effectiveDriverId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final reviews = await ReviewService.fetchDriverReviewsList(effectiveDriverId);

    // Calculate rating stats
    double total = 0.0;
    final Map<int, int> stars = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    final Map<String, int> tags = {};

    for (final r in reviews) {
      final ratingNum = (r['rating'] as num?)?.toDouble() ?? 5.0;
      total += ratingNum;
      final int roundedStar = ratingNum.round().clamp(1, 5);
      stars[roundedStar] = (stars[roundedStar] ?? 0) + 1;

      final dynamic feedbackTags = r['feedback_tags'];
      if (feedbackTags is List) {
        for (final t in feedbackTags) {
          final strTag = t.toString();
          tags[strTag] = (tags[strTag] ?? 0) + 1;
        }
      }
    }

    final double avg = reviews.isNotEmpty
        ? double.parse((total / reviews.length).toStringAsFixed(1))
        : 5.0;

    if (mounted) {
      setState(() {
        _reviews = reviews;
        _averageRating = avg;
        _starCounts = stars;
        _tagCounts = tags;
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final DateTime dt = DateTime.parse(timestamp.toString()).toLocal();
      final DateTime now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes.clamp(1, 59)}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom + 20;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: safeBottom,
      ),
      child: Column(
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
          const SizedBox(height: 14),

          // Header
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
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Passenger Reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textDark,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReviews,
                    color: AppColors.textDark,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Rating Summary Hero Box
                          _buildRatingSummaryCard(),
                          const SizedBox(height: 16),

                          // 2. Top Compliments Pill Tags (if any)
                          if (_tagCounts.isNotEmpty) ...[
                            Text(
                              'Top Compliments',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tagCounts.entries.map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySubtle,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${entry.value}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // 3. Reviews List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Reviews (${_reviews.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_reviews.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primarySubtle,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.rate_review_outlined,
                                      size: 32,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Reviews Yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ratings and feedback from your passengers will appear here after completed trips.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reviews.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildReviewItemCard(_reviews[index]);
                              },
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummaryCard() {
    final int total = _reviews.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Left: Big Rating Number & Stars
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isFull = (index + 1) <= _averageRating.round();
                    return Icon(
                      isFull ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  '$total review${total == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 80, color: AppColors.border),
          const SizedBox(width: 12),

          // Right: 5-Star Breakdown Bars
          Expanded(
            flex: 6,
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final int count = _starCounts[star] ?? 0;
                final double percent = total > 0 ? (count / total) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 16,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItemCard(Map<String, dynamic> review) {
    final passengerName = review['passenger_name'] ?? 'Passenger';
    final passengerAvatar = review['passenger_avatar_url'] as String?;
    final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
    final comment = review['comment']?.toString();
    final dynamic tagsList = review['feedback_tags'];
    final dateStr = _formatDate(review['created_at']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Rating & Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: ClipOval(
                  child: (passengerAvatar != null && passengerAvatar.isNotEmpty)
                      ? Image.network(
                          passengerAvatar,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 22,
                            color: AppColors.textDark,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: AppColors.textDark,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          (i + 1) <= rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 14,
                          color: const Color(0xFFF59E0B),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Feedback Tags
          if (tagsList is List && tagsList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagsList.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    tag.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Comment Quote Bubble
          if (comment != null && comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      comment.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
