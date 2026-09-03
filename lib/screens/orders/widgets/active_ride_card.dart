import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

enum RideCardType {
  upcoming, // Incoming request awaiting acceptance
  ongoing, // Active ride in progress (with phone & message buttons)
}

class ActiveRideCard extends StatelessWidget {
  final RideCardType cardType;
  final String rideStatus; // 'accepted', 'on_the_way', 'arrived', 'in_progress'
  final String passengerName;
  final String? passengerAvatarUrl;
  final String passengerRating;
  final String fare;
  final String distance;
  final String duration;
  final String pickupLocation;
  final String dropoffLocation;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCallPassenger;
  final VoidCallback? onMessagePassenger;
  final VoidCallback? onArrivedAtPickup;
  final VoidCallback? onStartRide;
  final VoidCallback? onCompleteRide;
  final VoidCallback? onGoToLocation;
  final VoidCallback? onCancelRide;
  final bool isAlerting;
  final double progressValue; // 0.0 to 1.0
  final int remainingSeconds; // 12 down to 0
  final String paymentMethod; // 'Online' or 'Cash'

  const ActiveRideCard({
    super.key,
    this.cardType = RideCardType.upcoming,
    this.rideStatus = 'accepted',
    this.passengerName = 'Sophia M.',
    this.passengerAvatarUrl,
    this.passengerRating = '4.9',
    this.fare = '18.50€',
    this.distance = '4.2 km',
    this.duration = '12 min',
    this.pickupLocation = 'Airport Terminal 2',
    this.dropoffLocation = 'Grand Hyatt Hotel, Central St.',
    this.onAccept,
    this.onDecline,
    this.onCallPassenger,
    this.onMessagePassenger,
    this.onArrivedAtPickup,
    this.onStartRide,
    this.onCompleteRide,
    this.onGoToLocation,
    this.onCancelRide,
    this.isAlerting = false,
    this.progressValue = 1.0,
    this.remainingSeconds = 12,
    this.paymentMethod = 'Online',
  });

  @override
  Widget build(BuildContext context) {
    final isOngoing = cardType == RideCardType.ongoing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlerting
              ? AppColors.primary
              : (isOngoing ? AppColors.primary.withOpacity(0.5) : AppColors.border),
          width: isAlerting ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isAlerting
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.shadowColor,
            blurRadius: isAlerting ? 20 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge & Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOngoing
                      ? AppColors.primarySubtle
                      : (isAlerting ? Colors.orange.withOpacity(0.15) : AppColors.primaryActiveBg),
                  borderRadius: BorderRadius.circular(20),
                  border: isOngoing ? Border.all(color: AppColors.primary.withOpacity(0.4)) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOngoing
                            ? (rideStatus == 'arrived'
                                ? const Color(0xFF22C55E)
                                : AppColors.primary)
                            : (isAlerting ? Colors.orange : AppColors.primary),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !isOngoing
                          ? (isAlerting ? 'Incoming Request (${remainingSeconds}s)' : 'New Trip Request')
                          : (rideStatus == 'accepted' || rideStatus == 'on_the_way'
                              ? 'On the Way to Pickup'
                              : (rideStatus == 'arrived' ? 'Arrived at Pickup' : 'Trip In Progress')),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOngoing
                            ? AppColors.textDark
                            : (isAlerting ? Colors.orange.shade800 : AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fare,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          paymentMethod.toLowerCase() == 'cash'
                              ? Icons.payments_rounded
                              : Icons.credit_card_rounded,
                          size: 11,
                          color: AppColors.textDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          paymentMethod.toLowerCase() == 'cash' ? 'Cash Payment' : 'Online Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Passenger info row + Call & Message Icon Buttons for Active Ride
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                ),
                child: ClipOval(
                  child: (passengerAvatarUrl != null && passengerAvatarUrl!.isNotEmpty)
                      ? Image.network(
                          passengerAvatarUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.textDark,
                            size: 26,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.textDark,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          passengerRating,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '• $distance ($duration)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Phone & Message Action Icon Buttons (Only for Ongoing Active Ride)
              if (isOngoing) ...[
                GestureDetector(
                  onTap: onCallPassenger,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onMessagePassenger,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 18,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Route Timeline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.border,
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppColors.textDark,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pickup
                    Text(
                      'PICKUP',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      pickupLocation,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dropoff
                    Text(
                      'DROPOFF',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      dropoffLocation,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons Section
          if (isOngoing)
            // Ongoing Active Ride Actions: Multi-step Action (Arrived -> Start -> Complete) & Navigation
            Column(
              children: [
                if (rideStatus == 'accepted' || rideStatus == 'on_the_way')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onArrivedAtPickup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.pin_drop_rounded,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      label: Text(
                        'Arrived at Pickup',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  )
                else if (rideStatus == 'arrived')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onStartRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: Text(
                        'Verify PIN & Start',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onCompleteRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      label: Text(
                        'Complete Trip',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onGoToLocation,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.65),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.14),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.near_me_rounded,
                                    color: AppColors.textDark,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      (rideStatus == 'accepted' || rideStatus == 'on_the_way')
                                          ? 'Navigate to Pickup'
                                          : 'Navigate to Dropoff',
                                      maxLines: 1,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_outward_rounded,
                                  color: AppColors.textDark,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onCancelRide != null) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onCancelRide,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEE2E2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          else
            // Upcoming Request Actions: Decline & Accept Ride with Progress Fill
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressValue.clamp(0.0, 1.0),
                                child: Container(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isAlerting
                                        ? 'Accept Ride (${remainingSeconds}s)'
                                        : 'Accept Ride',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: AppColors.textDark,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
