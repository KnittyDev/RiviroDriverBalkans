import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import 'auth_screen.dart';
import 'driver_onboarding_screen.dart';

class DriverApplicationPendingScreen extends StatefulWidget {
  final bool isRejected;
  final String? rejectionReason;

  const DriverApplicationPendingScreen({
    super.key,
    this.isRejected = false,
    this.rejectionReason,
  });

  @override
  State<DriverApplicationPendingScreen> createState() => _DriverApplicationPendingScreenState();
}

class _DriverApplicationPendingScreenState extends State<DriverApplicationPendingScreen> {
  bool _isChecking = false;
  late bool _rejectedState;
  String? _reason;

  @override
  void initState() {
    super.initState();
    _rejectedState = widget.isRejected;
    _reason = widget.rejectionReason;
    _checkStatusAutomatically();
  }

  Future<void> _checkStatusAutomatically() async {
    await _checkStatus(isManual: false);
  }

  Future<void> _checkStatus({bool isManual = true}) async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null) {
      setState(() => _isChecking = false);
      return;
    }

    try {
      final status = await AuthService.fetchDriverStatus(driverId);
      debugPrint('🔍 [PendingScreen] Current driver_status from Supabase: $status');

      if (!mounted) return;

      if (status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Application Approved! Welcome aboard.',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
        return;
      } else if (status == 'rejected') {
        setState(() {
          _rejectedState = true;
          _isChecking = false;
        });
      } else {
        setState(() {
          _rejectedState = false;
          _isChecking = false;
        });
        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Application is still under review by our safety team.',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
              backgroundColor: AppColors.textDark,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PendingScreen] Error checking status: $e');
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      AuthService.currentDriverNotifier.value = null;
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 20;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 30,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Animated Icon Card
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _rejectedState
                        ? const Color(0xFFFEE2E2)
                        : AppColors.primarySubtle,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_rejectedState ? Colors.red : AppColors.primary).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _rejectedState
                        ? Icons.error_outline_rounded
                        : Icons.hourglass_top_rounded,
                    size: 46,
                    color: _rejectedState
                        ? const Color(0xFFDC2626)
                        : AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _rejectedState
                    ? 'Application Needs Attention'
                    : 'Application Under Review',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _rejectedState
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _rejectedState
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _rejectedState
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _rejectedState ? 'ACTION REQUIRED' : 'PENDING APPROVAL',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _rejectedState
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Explanation Body
              Text(
                _rejectedState
                    ? (_reason != null && _reason!.isNotEmpty
                        ? _reason!
                        : 'Some of your submitted documents require updates. Please review and re-submit your vehicle and license scans.')
                    : 'Thank you for registering with Rivilo Driver! Our safety and compliance team is reviewing your vehicle details and license photos.\n\nReviews are typically completed within 24 to 48 hours. Once approved, you will have immediate access to accept ride requests.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),

              // Step Progress / Security Cards
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildStatusStep(
                      title: 'Account Registration',
                      subtitle: 'Completed successfully',
                      isCompleted: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Divider(color: AppColors.border, height: 20),
                    ),
                    _buildStatusStep(
                      title: 'Documents & Vehicle Verification',
                      subtitle: _rejectedState
                          ? 'Correction needed on uploaded scans'
                          : 'Under review by Rivilo Trust & Safety',
                      isCompleted: false,
                      isPending: !_rejectedState,
                      isRejected: _rejectedState,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Divider(color: AppColors.border, height: 20),
                    ),
                    _buildStatusStep(
                      title: 'Account Activation',
                      subtitle: 'Unlock driver dashboard and ride requests',
                      isCompleted: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (_rejectedState)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DriverOnboardingScreen(isResubmitting: true),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.edit_document, color: AppColors.textDark, size: 20),
                    label: Text(
                      'Update Application Documents',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : () => _checkStatus(isManual: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textDark),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppColors.textDark, size: 20),
                    label: Text(
                      _isChecking ? 'Checking Status...' : 'Check Status Now',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Log Out / Switch Account',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isPending = false,
    bool isRejected = false,
  }) {
    Color iconColor;
    Color bgColor;
    IconData icon;

    if (isCompleted) {
      iconColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFDCFCE7);
      icon = Icons.check_rounded;
    } else if (isRejected) {
      iconColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEE2E2);
      icon = Icons.priority_high_rounded;
    } else if (isPending) {
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFEF3C7);
      icon = Icons.schedule_rounded;
    } else {
      iconColor = AppColors.textInactive;
      bgColor = const Color(0xFFF1F5F9);
      icon = Icons.circle_outlined;
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
