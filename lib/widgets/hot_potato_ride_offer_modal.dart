import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/main_screen.dart';
import '../services/hot_potato_dispatch_service.dart';
import '../theme/app_theme.dart';

class HotPotatoRideOfferModal extends StatefulWidget {
  final RideOfferModel offer;
  final Future<bool> Function() onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTimeout;

  static BuildContext? _activeModalContext;

  static void dismissCurrentModal() {
    if (_activeModalContext != null && _activeModalContext!.mounted) {
      try {
        Navigator.of(_activeModalContext!).maybePop();
      } catch (_) {}
      _activeModalContext = null;
    }
  }

  const HotPotatoRideOfferModal({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
  });

  static Future<void> show({
    required BuildContext context,
    required RideOfferModel offer,
    required Future<bool> Function() onAccept,
    required VoidCallback onDecline,
    required VoidCallback onTimeout,
  }) {
    dismissCurrentModal();

    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        _activeModalContext = ctx;
        return HotPotatoRideOfferModal(
          offer: offer,
          onAccept: onAccept,
          onDecline: onDecline,
          onTimeout: onTimeout,
        );
      },
    ).whenComplete(() {
      _activeModalContext = null;
    });
  }

  @override
  State<HotPotatoRideOfferModal> createState() => _HotPotatoRideOfferModalState();
}

class _HotPotatoRideOfferModalState extends State<HotPotatoRideOfferModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _countdownTimer;
  late int _remainingSeconds;
  bool _isProcessingAccept = false;

  @override
  void initState() {
    super.initState();

    final diffSeconds = widget.offer.expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    _remainingSeconds = diffSeconds > 0 ? diffSeconds : 15;

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _remainingSeconds),
    );

    _progressController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 1) {
          _remainingSeconds -= 1;
        } else {
          _remainingSeconds = 0;
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _handleTimeout() {
    if (_isProcessingAccept) return;
    widget.onTimeout();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _handleAccept() async {
    if (_isProcessingAccept) return;
    setState(() => _isProcessingAccept = true);

    _countdownTimer?.cancel();
    _progressController.stop();

    // 1. Instant close and instant tab switch (0ms delay)
    if (mounted) {
      Navigator.of(context).maybePop();
    }
    MainScreen.switchToTab(1);

    // 2. Perform backend acceptance asynchronously in background
    await widget.onAccept();
  }

  void _handleDecline() {
    _countdownTimer?.cancel();
    _progressController.stop();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: 15s Circular Countdown Timer & Queue Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Queue Order Badge (e.g. "Exclusive Priority #1")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryActiveBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.textDark),
                      const SizedBox(width: 6),
                      Text(
                        'Priority Offer #${widget.offer.queueOrder}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Animated Circular 15s Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: 1.0 - _progressController.value,
                            strokeWidth: 4.5,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _remainingSeconds <= 5 ? Colors.redAccent : AppColors.textDark,
                            ),
                          );
                        },
                      ),
                    ),
                    Text(
                      '${_remainingSeconds}s',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 5 ? Colors.redAccent : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Fare & Ride Type Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Earnings',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.offer.fareAmount.toStringAsFixed(2)}€',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryActiveBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 16, color: AppColors.textDark),
                      const SizedBox(width: 6),
                      Text(
                        widget.offer.paymentMethod.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Passenger & Distance Info Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        if (widget.offer.passengerAvatarUrl != null && widget.offer.passengerAvatarUrl!.isNotEmpty)
                          ClipOval(
                            child: Image.network(
                              widget.offer.passengerAvatarUrl!,
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppColors.textDark,
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.person_rounded, size: 16, color: AppColors.textDark),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.offer.passengerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 16, color: AppColors.textDark),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.offer.distanceKm.toStringAsFixed(1)} km away',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route Card (Pickup & Destination)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.offer.pickupAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        height: 16,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.offer.destinationAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Accept (Primary) & Pass / Decline (Secondary)
            Row(
              children: [
                // Decline / Pass Hot Potato Button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isProcessingAccept ? null : _handleDecline,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Pass',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Accept Ride Button
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessingAccept ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isProcessingAccept
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.textDark,
                              ),
                            )
                          : Text(
                              'Accept Ride',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
