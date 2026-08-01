import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StatusToggleCard extends StatefulWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const StatusToggleCard({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  State<StatusToggleCard> createState() => _StatusToggleCardState();
}

class _StatusToggleCardState extends State<StatusToggleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isOnline ? AppColors.primary : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isOnline ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isOnline
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.shadowColor,
            blurRadius: widget.isOnline ? 20 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status Badge with Pulsating Green / Solid Red dot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isOnline
                      ? AppColors.textDark.withOpacity(0.15)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.isOnline
                        ? FadeTransition(
                            opacity: _pulseAnimation,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFF15803D), // Pulsating vibrant green
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444), // Solid red for offline
                              shape: BoxShape.circle,
                            ),
                          ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isOnline ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: widget.isOnline
                            ? AppColors.textDark
                            : const Color(0xFFEF4444),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Switch Toggle
              Transform.scale(
                scale: 0.9,
                child: Switch.adaptive(
                  value: widget.isOnline,
                  onChanged: widget.onToggle,
                  activeColor: AppColors.textDark,
                  activeTrackColor: Colors.white,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.isOnline ? 'You are Online' : 'You are Offline',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isOnline
                ? 'Searching for nearby ride requests...'
                : 'Toggle the switch above to start receiving ride requests.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: widget.isOnline
                  ? AppColors.textDark.withOpacity(0.75)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
