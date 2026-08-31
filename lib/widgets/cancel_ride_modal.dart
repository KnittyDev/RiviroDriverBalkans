import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ride_alert_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';

class CancelRideModal extends StatefulWidget {
  final String rideId;
  final String passengerName;
  final VoidCallback? onCancelled;

  const CancelRideModal({
    super.key,
    required this.rideId,
    required this.passengerName,
    this.onCancelled,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String rideId,
    required String passengerName,
    VoidCallback? onCancelled,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CancelRideModal(
        rideId: rideId,
        passengerName: passengerName,
        onCancelled: onCancelled,
      ),
    );
  }

  @override
  State<CancelRideModal> createState() => _CancelRideModalState();
}

class _CancelRideModalState extends State<CancelRideModal> {
  final List<String> _cancelReasons = [
    'Passenger did not show up',
    'Passenger unreachable / wrong location',
    'Vehicle problem / Flat tire',
    'Heavy traffic / Road impassable',
    'Emergency / Personal issue',
    'Other reason',
  ];

  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmCancel() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a reason for cancellation',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final finalReason = _selectedReason == 'Other reason' &&
            _otherReasonController.text.trim().isNotEmpty
        ? _otherReasonController.text.trim()
        : _selectedReason!;

    setState(() => _isProcessing = true);

    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // 1. Update rides table in Supabase
      await Supabase.instance.client.from('rides').update({
        'status': 'cancelled',
        'cancellation_reason': finalReason,
        'cancelled_by': 'driver',
        'cancelled_at': nowUtc,
        'assigned_driver_id': null,
        'updated_at': nowUtc,
      }).eq('id', widget.rideId);

      // 2. Update ride_offers for this ride
      await Supabase.instance.client
          .from('ride_offers')
          .update({'status': 'cancelled', 'updated_at': nowUtc})
          .eq('ride_id', widget.rideId);

      // 3. Clear alerts & notifications
      RideAlertService().stopAlert();
      PushNotificationService.cancelNotification(
          widget.rideId.hashCode & 0x7FFFFFFF);

      widget.onCancelled?.call();

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trip cancelled successfully.',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling trip: $e', style: GoogleFonts.poppins(fontSize: 12.5)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(22, 12, 22, (bottomPadding > 0 ? bottomPadding + 14 : 28) + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancel Trip',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Trip with ${widget.passengerName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Notice Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cancelling will release this trip and notify the passenger. Please state the reason.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF991B1B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Select Cancellation Reason',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 10),

            // Radio options list
            ..._cancelReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.red.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : AppColors.border,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? Colors.redAccent : AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reason,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.textDark : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (_selectedReason == 'Other reason') ...[
              const SizedBox(height: 6),
              TextField(
                controller: _otherReasonController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons (Confirm Cancel / Keep Trip)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Keep Trip',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleConfirmCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Confirm Cancellation',
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
      ),
    ),
    );
  }
}
