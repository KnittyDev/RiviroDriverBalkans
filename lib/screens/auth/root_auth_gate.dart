import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import 'auth_screen.dart';
import 'driver_application_pending_screen.dart';
import 'driver_onboarding_screen.dart';

class RootAuthGate extends StatefulWidget {
  const RootAuthGate({super.key});

  @override
  State<RootAuthGate> createState() => _RootAuthGateState();
}

class _RootAuthGateState extends State<RootAuthGate> {
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkInitialAuthAndStatus();
  }

  Future<void> _checkInitialAuthAndStatus() async {
    try {
      // 1. Initialize local session if available
      await AuthService.init();

      final currentUser = Supabase.instance.client.auth.currentUser;
      final cachedDriver = AuthService.currentDriverNotifier.value;
      final driverId = cachedDriver?.id ?? currentUser?.id;

      if (driverId == null || driverId.isEmpty) {
        // No driver session exists
        if (mounted) {
          setState(() {
            _targetScreen = const AuthScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch driver profile and status live from Supabase
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      if (profileRow == null) {
        if (mounted) {
          setState(() {
            _targetScreen = const AuthScreen();
            _isLoading = false;
          });
        }
        return;
      }

      final profile = DriverProfileModel.fromJson(profileRow);
      await AuthService.setCurrentDriver(profile);

      final status = profile.driverStatus; // 'approved', 'pending', 'rejected'
      final vehicleModel = profileRow['vehicle_model']?.toString() ?? '';
      final licenseNum = profileRow['license_number']?.toString() ?? '';
      final hasCompletedOnboarding = vehicleModel.isNotEmpty &&
          vehicleModel != 'Mercedes-Benz E-Class' &&
          licenseNum.isNotEmpty &&
          licenseNum != 'DL-9821-48201';

      debugPrint('🚪 [RootAuthGate] Driver: ${profile.fullName} | Status: $status | HasOnboarded: $hasCompletedOnboarding');

      if (!mounted) return;

      if (status == 'approved') {
        setState(() {
          _targetScreen = const MainScreen();
          _isLoading = false;
        });
      } else if (status == 'rejected') {
        setState(() {
          _targetScreen = const DriverApplicationPendingScreen(isRejected: true);
          _isLoading = false;
        });
      } else {
        // Status is 'pending'
        if (!hasCompletedOnboarding) {
          setState(() {
            _targetScreen = const DriverOnboardingScreen();
            _isLoading = false;
          });
        } else {
          setState(() {
            _targetScreen = const DriverApplicationPendingScreen();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ [RootAuthGate] Auth gate evaluation error: $e');
      if (mounted) {
        setState(() {
          _targetScreen = const MainScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _targetScreen == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 48,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rivilo Driver',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _targetScreen!;
  }
}
