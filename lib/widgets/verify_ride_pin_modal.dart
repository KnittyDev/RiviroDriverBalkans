import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/driver_stats_service.dart';
import '../theme/app_theme.dart';

class VerifyRidePinModal extends StatefulWidget {
  final String rideId;
  final String passengerName;
  final String? passengerAvatarUrl;

  const VerifyRidePinModal({
    super.key,
    required this.rideId,
    this.passengerName = 'Passenger',
    this.passengerAvatarUrl,
  });

  /// Opens the PIN Verification modal. Returns true if PIN was verified and ride started.
  static Future<bool> show(
    BuildContext context, {
    required String rideId,
    String passengerName = 'Passenger',
    String? passengerAvatarUrl,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VerifyRidePinModal(
        rideId: rideId,
        passengerName: passengerName,
        passengerAvatarUrl: passengerAvatarUrl,
      ),
    );
    return result ?? false;
  }

  @override
  State<VerifyRidePinModal> createState() => _VerifyRidePinModalState();
}

class _VerifyRidePinModalState extends State<VerifyRidePinModal>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  int _pinLength = 6; // Default to 6 digits, auto-adapted if ride has 4 digits
  bool _isVerifying = false;
  String? _errorMessage;
  bool _isSuccess = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    _fetchExpectedPinLength();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpectedPinLength() async {
    try {
      final rideRow = await Supabase.instance.client
          .from('rides')
          .select('pin_code')
          .eq('id', widget.rideId)
          .maybeSingle();

      if (rideRow != null && rideRow['pin_code'] != null) {
        final pinStr = rideRow['pin_code'].toString().trim();
        if (pinStr.length >= 4 && pinStr.length <= 6 && mounted) {
          setState(() {
            _pinLength = pinStr.length;
          });
        }
      }
    } catch (_) {}
  }

  void _onKeyPressed(String key) {
    if (_isVerifying || _isSuccess) return;

    HapticFeedback.lightImpact();

    if (_enteredPin.length < _pinLength) {
      setState(() {
        _errorMessage = null;
        _enteredPin += key;
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPinCode();
      }
    }
  }

  void _onBackspace() {
    if (_isVerifying || _isSuccess) return;

    HapticFeedback.selectionClick();

    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPinCode() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔑 [VerifyRidePinModal] Verifying PIN for ride ${widget.rideId}...');

      final rideRow = await Supabase.instance.client
          .from('rides')
          .select('id, pin_code, status')
          .eq('id', widget.rideId)
          .maybeSingle();

      if (rideRow == null) {
        throw Exception('Ride not found');
      }

      final String? expectedPin = rideRow['pin_code']?.toString().trim();
      final String entered = _enteredPin.trim();

      // Normalize check: if pin_code is null or matches entered PIN
      final bool isMatch = (expectedPin != null && expectedPin.isNotEmpty)
          ? (entered == expectedPin)
          : true; // Fallback if no pin in DB

      if (isMatch) {
        // Success!
        HapticFeedback.heavyImpact();
        setState(() {
          _isSuccess = true;
          _isVerifying = false;
        });

        // Update ride status in Supabase to in_progress
        await Supabase.instance.client.from('rides').update({
          'status': 'in_progress',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.rideId);

        DriverStatsService.fetchDriverLiveStats();

        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Incorrect PIN
        HapticFeedback.vibrate();
        _shakeController.forward(from: 0.0);

        setState(() {
          _isVerifying = false;
          _errorMessage = 'Incorrect PIN code. Please ask the passenger.';
          _enteredPin = '';
        });
      }
    } catch (e) {
      debugPrint('❌ [VerifyRidePinModal] Verification error: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Connection error. Please try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom + 14;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset + safeBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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

          // Header (Properly bounded with Expanded)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pin_rounded,
                  color: AppColors.textDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Passenger PIN Verification',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Passenger Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarySubtle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: ClipOval(
                    child: (widget.passengerAvatarUrl != null &&
                            widget.passengerAvatarUrl!.isNotEmpty)
                        ? Image.network(
                            widget.passengerAvatarUrl!,
                            width: 40,
                            height: 40,
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
                        widget.passengerName,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ask the passenger for their $_pinLength-digit ride PIN',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // PIN Input Display Boxes (Expanded children guarantee 100% responsive 0px overflow)
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: List.generate(_pinLength, (index) {
                  final bool isFilled = index < _enteredPin.length;
                  final bool isCurrent = index == _enteredPin.length && !_isSuccess;
                  final String char = isFilled ? _enteredPin[index] : '';

                  Color borderColor = AppColors.border;
                  Color bgColor = const Color(0xFFF8FAFC);

                  if (_isSuccess) {
                    borderColor = const Color(0xFF22C55E);
                    bgColor = const Color(0xFFDCFCE7);
                  } else if (_errorMessage != null) {
                    borderColor = Colors.red.shade400;
                    bgColor = Colors.red.shade50;
                  } else if (isCurrent) {
                    borderColor = AppColors.primary;
                    bgColor = Colors.white;
                  } else if (isFilled) {
                    borderColor = AppColors.textDark;
                    bgColor = Colors.white;
                  }

                  return Expanded(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: isCurrent || isFilled || _isSuccess ? 2.0 : 1.2,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isSuccess
                            ? const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF16A34A),
                                size: 22,
                              )
                            : Text(
                                char,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Error / Verifying Message Banner
          const SizedBox(height: 10),
          SizedBox(
            height: 20,
            child: _isVerifying
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verifying PIN...',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : _isSuccess
                        ? Text(
                            'PIN Verified! Starting Ride...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Text(
                            'Enter passenger\'s $_pinLength-digit code to start trip',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
          ),
          const SizedBox(height: 14),

          // Tactile On-Screen Numeric Keypad
          _buildNumericKeypad(),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox(height: 46));
              } else if (key == 'backspace') {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 46,
                    child: Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _onBackspace,
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Icon(
                            Icons.backspace_outlined,
                            size: 20,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 46,
                    child: Material(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _onKeyPressed(key),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Text(
                            key,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
