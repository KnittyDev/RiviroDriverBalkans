import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/review_service.dart';
import '../../services/ride_alert_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_reviews_modal.dart';
import 'pages/vehicle_settings_screen.dart';
import 'pages/iban_payout_settings_screen.dart';
import 'pages/driver_license_screen.dart';
import 'pages/vehicle_insurance_screen.dart';
import 'pages/terms_of_service_screen.dart';
import 'pages/privacy_policy_screen.dart';
import 'pages/driver_faq_screen.dart';
import '../../widgets/driver_growth_boost_modal.dart';
import '../../widgets/boost_calculator_modal.dart';
import '../../widgets/withdraw_history_modal.dart';
import '../../widgets/withdraw_modal.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _audioAlertsEnabled = true;
  bool _hapticFeedbackEnabled = true;
  bool _autoNavigationEnabled = true;
  String _selectedLanguage = 'English';
  String _appVersion = 'v1.0.0 (Build 1)';
  String _driverRating = '5.0';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadDriverRating();
    _loadAlertPreferences();
  }

  Future<void> _loadAlertPreferences() async {
    await RideAlertService.initPreferences();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _audioAlertsEnabled = RideAlertService.audioAlertsEnabled;
          _hapticFeedbackEnabled = RideAlertService.hapticFeedbackEnabled;
          _autoNavigationEnabled = prefs.getBool('setting_auto_navigation') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAudioAlerts(bool val) async {
    setState(() => _audioAlertsEnabled = val);
    await RideAlertService.setAudioAlerts(val);
  }

  Future<void> _toggleHapticFeedback(bool val) async {
    setState(() => _hapticFeedbackEnabled = val);
    await RideAlertService.setHapticFeedback(val);
  }

  Future<void> _toggleAutoNavigation(bool val) async {
    setState(() => _autoNavigationEnabled = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setting_auto_navigation', val);
    } catch (_) {}
  }

  Future<void> _loadDriverRating() async {
    final driverId = AuthService.currentDriverNotifier.value?.id;
    if (driverId != null && driverId.isNotEmpty) {
      final avg = await ReviewService.fetchDriverAverageRating(driverId);
      if (avg != null && mounted) {
        setState(() {
          _driverRating = avg.toStringAsFixed(1);
        });
      }
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version} (Build ${info.buildNumber})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = 'v1.0.0 (Build 1)';
        });
      }
    }
  }

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final languages = [
          {'name': 'English', 'flag': '🇬🇧', 'native': 'English'},
          {'name': 'Polish', 'flag': '🇵🇱', 'native': 'Polski'},
          {'name': 'Turkish', 'flag': '🇹🇷', 'native': 'Türkçe'},
          {'name': 'German', 'flag': '🇩🇪', 'native': 'Deutsch'},
          {'name': 'French', 'flag': '🇫🇷', 'native': 'Français'},
          {'name': 'Spanish', 'flag': '🇪🇸', 'native': 'Español'},
        ];

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              // Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: AppColors.textDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select App Language',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),

              // Language Options List
              ...languages.map((lang) {
                final isSelected = _selectedLanguage == lang['name'];
                return ListTile(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang['name']!;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'App language changed to ${lang['native']} (${lang['name']})',
                          style: GoogleFonts.poppins(fontSize: 12.5),
                        ),
                        backgroundColor: AppColors.textDark,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Text(
                    lang['flag']!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    lang['name']!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    lang['native']!,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                      : null,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your driver account? You will go offline and will not receive any ride requests.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      await AuthService.logout();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged out successfully.',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: AppColors.textDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Driver Account Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ProfileService.buildAvatarWidget(
                    size: 56,
                    showCameraBadge: true,
                    onTap: () => ProfileService.showPhotoOptionsBottomSheet(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ValueListenableBuilder<DriverProfileModel?>(
                      valueListenable: AuthService.currentDriverNotifier,
                      builder: (context, driver, child) {
                        final name = driver?.fullName.isNotEmpty == true ? driver!.fullName : 'Driver Profile';
                        final email = driver?.email ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            // See Ratings Pill Button
                            GestureDetector(
                              onTap: () => DriverReviewsModal.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_driverRating ★ • See Ratings',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.textDark),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Help & Driver FAQ (Top Priority)
            _buildSectionTitle('Help & Driver Guide'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSimpleTile(
                title: 'Driver FAQ & Handbook',
                subtitle: 'Hot Potato offers, navigation, PIN verification, wallet & payouts',
                icon: Icons.help_outline_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DriverFaqScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // 2. Performance & Ratings
            _buildSectionTitle('Performance & Ratings'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSimpleTile(
                title: 'Ratings & Reviews',
                subtitle: '$_driverRating ★ • View passenger feedback & compliments',
                icon: Icons.star_rounded,
                onTap: () => DriverReviewsModal.show(context),
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Get More Rides',
                subtitle: 'Tips on ratings, chargers & peak hours',
                icon: Icons.rocket_launch_rounded,
                onTap: () => DriverGrowthBoostModal.show(context),
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Calculate Boost Score',
                subtitle: 'Test your potential dispatch score live',
                icon: Icons.calculate_rounded,
                onTap: () => BoostCalculatorModal.show(context),
              ),
            ]),
            const SizedBox(height: 24),

            // 3. Earnings & Finance
            _buildSectionTitle('Earnings & Finance'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSimpleTile(
                title: 'Wallet Transactions',
                subtitle: 'All trip earnings, payouts & transactions',
                icon: Icons.receipt_long_rounded,
                onTap: () => WithdrawHistoryModal.show(context),
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Withdraw Balance',
                subtitle: 'Request a payout to your bank account',
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => WithdrawModal.show(context),
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Bank & Payout Settings',
                subtitle: 'Manage your destination bank & IBAN',
                icon: Icons.account_balance_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const IbanPayoutSettingsScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // 4. Documents & Compliance
            _buildSectionTitle('Documents & Compliance'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSimpleTile(
                title: 'Vehicle Settings',
                icon: Icons.directions_car_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VehicleSettingsScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Driver License & Verification',
                icon: Icons.badge_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DriverLicenseScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Vehicle Insurance',
                icon: Icons.shield_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VehicleInsuranceScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // 3. Preferences & App Settings
            _buildSectionTitle('Preferences & App Settings'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSwitchTile(
                title: 'Auto Start Navigation',
                subtitle: 'Automatically open map on trip accept',
                icon: Icons.navigation_rounded,
                value: _autoNavigationEnabled,
                onChanged: _toggleAutoNavigation,
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'App Language',
                subtitle: 'Tap to change language',
                icon: Icons.language_rounded,
                trailingText: _selectedLanguage,
                onTap: () => _showLanguageBottomSheet(context),
              ),
            ]),
            const SizedBox(height: 24),

            // 4. Audio & Ride Alerts
            _buildSectionTitle('Audio & Ride Alerts'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSwitchTile(
                title: 'Ride Request Sound Alerts',
                subtitle: 'Play 1.1s audio clip on incoming requests',
                icon: Icons.volume_up_rounded,
                value: _audioAlertsEnabled,
                onChanged: _toggleAudioAlerts,
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSwitchTile(
                title: 'Haptic Vibration Feedback',
                subtitle: 'Vibrate device on alert pulses',
                icon: Icons.vibration_rounded,
                value: _hapticFeedbackEnabled,
                onChanged: _toggleHapticFeedback,
              ),
            ]),
            const SizedBox(height: 24),

            // 5. Driver Authentication & Account Switch (Hidden if driver is already logged in)
            if (AuthService.currentDriverNotifier.value == null &&
                Supabase.instance.client.auth.currentUser == null) ...[
              _buildSectionTitle('Driver Account'),
              const SizedBox(height: 10),
              _buildSettingsContainer([
                _buildSimpleTile(
                  title: 'Sign In / Register Driver Account',
                  subtitle: 'Log in or create a new official Driver profile',
                  icon: Icons.account_circle_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
            ],

            // 6. System & Legal Policies
            _buildSectionTitle('Legal & System'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSimpleTile(
                title: 'Terms of Service',
                subtitle: 'EU Transport Regulations Compliant',
                icon: Icons.gavel_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'Privacy Policy',
                subtitle: 'GDPR & EU Data Protection Standard',
                icon: Icons.lock_outline_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              _buildSimpleTile(
                title: 'App Version',
                subtitle: _appVersion,
                icon: Icons.info_outline_rounded,
                trailingText: 'Latest',
              ),
            ]),
            const SizedBox(height: 24),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutConfirmationDialog(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryActiveBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTile({
    required String title,
    String? subtitle,
    required IconData icon,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryActiveBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textDark, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryActiveBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                trailingText,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
          else if (trailingText == null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
