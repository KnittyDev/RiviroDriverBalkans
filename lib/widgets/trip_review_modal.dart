import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

class TripReviewModal extends StatefulWidget {
  final String rideId;
  final String passengerName;
  final String? passengerAvatarUrl;
  final String? passengerId;
  final String fare;
  final String tripId;

  const TripReviewModal({
    super.key,
    this.rideId = '',
    this.passengerName = 'Passenger',
    this.passengerAvatarUrl,
    this.passengerId,
    this.fare = '24.50€',
    this.tripId = '#TR-8921',
  });

  static Future<bool?> show(
    BuildContext context, {
    String rideId = '',
    String passengerName = 'Passenger',
    String? passengerAvatarUrl,
    String? passengerId,
    String fare = '24.50€',
    String tripId = '#TR-8921',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripReviewModal(
        rideId: rideId,
        passengerName: passengerName,
        passengerAvatarUrl: passengerAvatarUrl,
        passengerId: passengerId,
        fare: fare,
        tripId: tripId,
      ),
    );
  }

  @override
  State<TripReviewModal> createState() => _TripReviewModalState();
}

class _TripReviewModalState extends State<TripReviewModal> with SingleTickerProviderStateMixin {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedTags = {'Polite 🤝', 'On Time ⏱️'};
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  List<String> get _currentQuickTags {
    if (_selectedRating >= 4) {
      return [
        'Polite 🤝',
        'On Time ⏱️',
        'Clean ✨',
        'Friendly 😊',
        'Smooth Trip 🚗',
      ];
    } else {
      return [
        'Late ⏱️',
        'Impolite 🙁',
        'Mess in Car 🧼',
        'Route Demands 🗺️',
        'Unresponsive 📱',
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onStarTapped(int rating) {
    setState(() {
      if ((_selectedRating >= 4 && rating < 4) || (_selectedRating < 4 && rating >= 4)) {
        _selectedTags.clear();
      }
      _selectedRating = rating;
    });

    // Trigger haptic vibration feedback
    Vibration.hasVibrator().then((hasVibe) {
      if (hasVibe == true) {
        Vibration.vibrate(duration: 35);
      }
    });

    // Trigger popup wiggle & bounce animation
    _animController.forward(from: 0.0);
  }

  String get _ratingLabel {
    switch (_selectedRating) {
      case 1:
        return 'Difficult Passenger 😡';
      case 2:
        return 'Below Expectations 🙁';
      case 3:
        return 'Average Trip 😐';
      case 4:
        return 'Good Passenger 🙂';
      case 5:
      default:
        return 'Excellent Passenger! ⭐⭐⭐⭐⭐';
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final success = await ReviewService.submitPassengerReview(
      rideId: widget.rideId,
      passengerId: widget.passengerId,
      rating: _selectedRating.toDouble(),
      feedbackTags: _selectedTags.toList(),
      comment: _commentController.text,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review submitted for ${widget.passengerName} ($_selectedRating Stars)!',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit review. Please try again.',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  void _skipReview() {
    ReviewService.dismissPassengerReview(rideId: widget.rideId);
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset + safeBottomInset,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle Bar
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title Row
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
                      child: const Icon(Icons.rate_review_rounded, color: AppColors.textDark, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Rate Passenger',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _skipReview,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Passenger Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySubtle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: ClipOval(
                      child: (widget.passengerAvatarUrl != null && widget.passengerAvatarUrl!.isNotEmpty)
                          ? Image.network(
                              widget.passengerAvatarUrl!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person_rounded,
                                size: 28,
                                color: AppColors.textDark,
                              ),
                            )
                          : const Icon(Icons.person_rounded, size: 28, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.passengerName,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Trip ID: ${widget.tripId}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.fare,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Animated Tactile Wiggling Star Selector
            Text(
              'How was your trip with ${widget.passengerName}?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starNumber = index + 1;
                    final isSelected = starNumber <= _selectedRating;
                    final isTargetStar = starNumber == _selectedRating;

                    return GestureDetector(
                      onTap: () => _onStarTapped(starNumber),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Transform.scale(
                          scale: isTargetStar ? _scaleAnimation.value : 1.0,
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 44,
                            color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 8),

            // Selected Rating Text Feedback
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _ratingLabel,
                key: ValueKey(_selectedRating),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Choice Tags
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedRating >= 4 ? 'What went well? ✨' : 'What could be improved? 🛠️',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _currentQuickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Optional Comment Input Box
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Optional Note',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 6),

            TextField(
              controller: _commentController,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Write a note about the passenger (optional)...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Rating',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
