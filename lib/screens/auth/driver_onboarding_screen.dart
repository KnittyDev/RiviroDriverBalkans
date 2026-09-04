import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/document_upload_service.dart';
import '../../theme/app_theme.dart';
import 'auth_screen.dart';
import 'driver_application_pending_screen.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final bool isResubmitting;

  const DriverOnboardingScreen({
    super.key,
    this.isResubmitting = false,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Operating Country
  String _selectedCountry = 'MK'; // Default to North Macedonia

  final List<Map<String, String>> _countries = [
    {'code': 'MK', 'name': 'North Macedonia', 'flag': '🇲🇰', 'currency': 'MKD'},
    {'code': 'ME', 'name': 'Montenegro', 'flag': '🇲🇪', 'currency': 'EUR (€)'},
    {'code': 'AL', 'name': 'Albania', 'flag': '🇦🇱', 'currency': 'LEK'},
    {'code': 'RS', 'name': 'Serbia', 'flag': '🇷🇸', 'currency': 'RSD'},
  ];

  // Step 2: Vehicle
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();
  final TextEditingController _vehicleColorController = TextEditingController();
  final TextEditingController _carYearController = TextEditingController();

  // Step 3: Bank / Payout
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _swiftController = TextEditingController();

  // Step 4: License & Photos
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _licenseCategoryController =
      TextEditingController(text: 'Category B (Passenger Car)');
  final TextEditingController _licenseExpiryController = TextEditingController();

  File? _frontImageFile;
  File? _backImageFile;
  String? _frontLicenseUrl;
  String? _backLicenseUrl;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  // Driver Profile Photo
  File? _profileImageFile;
  String? _profileImageUrl;
  bool _isUploadingProfilePhoto = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfileData();
  }

  @override
  void dispose() {
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _carYearController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    _licenseNumberController.dispose();
    _licenseCategoryController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfileData() async {
    final driver = AuthService.currentDriverNotifier.value;
    final driverId = driver?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (driverId == null) return;

    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      if (row != null && mounted) {
        setState(() {
          final c = row['account_country']?.toString().toUpperCase();
          if (c != null && _countries.any((element) => element['code'] == c)) {
            _selectedCountry = c;
          }
          final vModel = row['vehicle_model']?.toString() ?? '';
          if (vModel.isNotEmpty && vModel != 'Mercedes-Benz E-Class') {
            _vehicleModelController.text = vModel;
          }

          final vPlate = row['vehicle_plate']?.toString() ?? '';
          if (vPlate.isNotEmpty && vPlate != 'PG-TX-789') {
            _vehiclePlateController.text = vPlate;
          }

          final vColor = row['vehicle_color']?.toString() ?? '';
          if (vColor.isNotEmpty && vColor != 'Black Metallic' && vColor != 'Standard') {
            _vehicleColorController.text = vColor;
          }

          final cYear = row['car_year']?.toString() ?? '';
          if (cYear.isNotEmpty && cYear != '2022') {
            _carYearController.text = cYear;
          }

          final bName = row['bank_name']?.toString() ?? '';
          if (bName.isNotEmpty && !bName.contains('NLB Banka AD Podgorica')) {
            _bankNameController.text = bName;
          }

          _accountHolderController.text = row['account_holder_name']?.toString() ??
              row['full_name']?.toString() ??
              driver?.fullName ??
              '';

          final bIban = row['iban']?.toString() ?? '';
          if (bIban.isNotEmpty && !bIban.contains('ME255300000012345678')) {
            _ibanController.text = bIban;
          }

          final bSwift = row['swift_bic']?.toString() ?? '';
          if (bSwift.isNotEmpty && bSwift != 'NLBMMEPG') {
            _swiftController.text = bSwift;
          }

          final lNum = row['license_number']?.toString() ?? '';
          if (lNum.isNotEmpty && lNum != 'DL-9821-48201') {
            _licenseNumberController.text = lNum;
          }

          if (row['license_category']?.toString().isNotEmpty == true) {
            _licenseCategoryController.text = row['license_category'].toString();
          }

          final lExp = row['license_expiry_date']?.toString() ?? '';
          if (lExp.isNotEmpty && lExp != '14/08/2028') {
            _licenseExpiryController.text = lExp;
          }

          _frontLicenseUrl = row['license_front_url']?.toString();
          _backLicenseUrl = row['license_back_url']?.toString();
          _profileImageUrl = row['avatar_url']?.toString();
        });
      }
    } catch (e) {
      debugPrint('⚠️ [DriverOnboarding] Error preloading profile: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365 * 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2045),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textDark,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDay = picked.day.toString().padLeft(2, '0');
      final formattedMonth = picked.month.toString().padLeft(2, '0');
      setState(() {
        controller.text = '$formattedDay/$formattedMonth/${picked.year}';
      });
    }
  }

  void _showImageSourcePicker(bool isFront) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFront ? 'Upload License (Front Side)' : 'Upload License (Back Side)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.textDark),
              ),
              title: Text('Take Photo with Camera', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadLicense(isFront, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.textDark),
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadLicense(isFront, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadLicense(bool isFront, ImageSource source) async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver session not found. Please log in again.')),
      );
      return;
    }

    final file = await DocumentUploadService.pickDocumentImage(source);
    if (file == null) return;

    setState(() {
      if (isFront) {
        _frontImageFile = file;
        _isUploadingFront = true;
      } else {
        _backImageFile = file;
        _isUploadingBack = true;
      }
    });

    final uploadedUrl = await DocumentUploadService.uploadLicenseDocument(
      file: file,
      driverId: driverId,
      isFront: isFront,
    );

    if (!mounted) return;

    setState(() {
      if (isFront) {
        _isUploadingFront = false;
        if (uploadedUrl != null) _frontLicenseUrl = uploadedUrl;
      } else {
        _isUploadingBack = false;
        if (uploadedUrl != null) _backLicenseUrl = uploadedUrl;
      }
    });

    if (uploadedUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isFront ? 'Front' : 'Back'} side uploaded to ID verifications!',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showProfilePhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Driver Profile Photo',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.textDark),
              ),
              title: Text('Take a Selfie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.textDark),
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadProfilePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null) {
      _showErrorSnackBar('Driver session not found. Please log in again.');
      return;
    }

    final file = await DocumentUploadService.pickDocumentImage(source);
    if (file == null) return;

    setState(() {
      _profileImageFile = file;
      _isUploadingProfilePhoto = true;
    });

    final uploadedUrl = await DocumentUploadService.uploadLicenseDocument(
      file: file,
      driverId: driverId,
      isFront: true,
    );

    if (!mounted) return;

    setState(() {
      _isUploadingProfilePhoto = false;
      if (uploadedUrl != null) _profileImageUrl = uploadedUrl;
    });

    if (uploadedUrl != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'avatar_url': uploadedUrl,
        }).eq('id', driverId);
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile photo uploaded successfully!',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } else {
      _showErrorSnackBar('Photo upload failed. Please try again.');
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_selectedCountry.isEmpty) {
        _showErrorSnackBar('Please select your operating country.');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_profileImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)) {
        _showErrorSnackBar('Please take a selfie or upload your profile photo.');
        return false;
      }
    } else if (_currentStep == 2) {
      if (_vehicleModelController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter vehicle make and model.');
        return false;
      }
      if (_vehiclePlateController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter vehicle license plate.');
        return false;
      }
      if (_carYearController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter vehicle manufacturing year.');
        return false;
      }
    } else if (_currentStep == 3) {
      if (_bankNameController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter bank name.');
        return false;
      }
      if (_accountHolderController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter account holder name.');
        return false;
      }
      if (_ibanController.text.trim().length < 8) {
        _showErrorSnackBar('Please enter a valid IBAN.');
        return false;
      }
    } else if (_currentStep == 4) {
      if (_licenseNumberController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter driver license number.');
        return false;
      }
      if (_licenseExpiryController.text.trim().isEmpty) {
        _showErrorSnackBar('Please select license expiry date.');
        return false;
      }
      if (_frontLicenseUrl == null && _frontImageFile == null) {
        _showErrorSnackBar('Please upload front side of your driver license.');
        return false;
      }
      if (_backLicenseUrl == null && _backImageFile == null) {
        _showErrorSnackBar('Please upload back side of your driver license.');
        return false;
      }
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12.5)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_validateCurrentStep()) return;

    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null) {
      _showErrorSnackBar('Session expired. Please log in again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final cleanIban = _ibanController.text.replaceAll(' ', '').trim().toUpperCase();

      await Supabase.instance.client.from('profiles').update({
        'account_country': _selectedCountry,
        if (_profileImageUrl != null) 'avatar_url': _profileImageUrl,
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_plate': _vehiclePlateController.text.trim().toUpperCase(),
        'vehicle_color': _vehicleColorController.text.trim().isNotEmpty
            ? _vehicleColorController.text.trim()
            : 'Standard',
        'car_year': _carYearController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'account_holder_name': _accountHolderController.text.trim(),
        'iban': cleanIban,
        'swift_bic': _swiftController.text.trim().toUpperCase(),
        'license_number': _licenseNumberController.text.trim().toUpperCase(),
        'license_category': _licenseCategoryController.text.trim(),
        'license_expiry_date': _licenseExpiryController.text.trim(),
        if (_frontLicenseUrl != null) 'license_front_url': _frontLicenseUrl,
        if (_backLicenseUrl != null) 'license_back_url': _backLicenseUrl,
        'driver_status': 'pending',
        'is_license_verified': false,
        'updated_at': nowUtcIso,
      }).eq('id', driverId);

      // Refresh local profile
      await AuthService.fetchDriverStatus(driverId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application submitted successfully! Our safety team will review it.',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DriverApplicationPendingScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('❌ [DriverOnboarding] Error submitting application: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackBar('Submission failed: $e');
      }
    }
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Exit Onboarding?',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Text(
          'You can log out now and finish your driver registration anytime later.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Log Out', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 20;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
        title: Text(
          'Driver Onboarding',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          Center(
            child: Text(
              'Step ${_currentStep + 1} of 5',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
            onPressed: () => _showExitConfirmation(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 5,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Bottom Navigation Buttons
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: safeBottomInset,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textDark,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                if (_currentStep < 4) {
                                  if (_validateCurrentStep()) {
                                    setState(() => _currentStep++);
                                  }
                                } else {
                                  _submitApplication();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textDark,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentStep == 4 ? 'Submit Application' : 'Continue',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      _currentStep == 4
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: AppColors.textDark,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Country();
      case 1:
        return _buildStep2ProfilePhoto();
      case 2:
        return _buildStep3Vehicle();
      case 3:
        return _buildStep4Bank();
      case 4:
        return _buildStep5LicenseAndPhotos();
      default:
        return const SizedBox();
    }
  }

  // STEP 1: Operating Country
  Widget _buildStep1Country() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Operating Country',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the country where you will operate. Your wallet currency and dispatch zone will be configured accordingly.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        // Country Options
        ..._countries.map((c) {
          final isSelected = _selectedCountry == c['code'];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySubtle : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () => setState(() => _selectedCountry = c['code']!),
              leading: Text(c['flag']!, style: const TextStyle(fontSize: 32)),
              title: Text(
                c['name']!,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: Text(
                'Currency: ${c['currency']}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.textDark, size: 22)
                  : const Icon(Icons.circle_outlined, color: AppColors.border, size: 22),
            ),
          );
        }),
      ],
    );
  }

  // STEP 2: Driver Profile Photo (Dedicated Step)
  Widget _buildStep2ProfilePhoto() {
    final hasPhoto = _profileImageFile != null ||
        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver Profile Photo',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload a clear forward-facing portrait so passengers can easily recognize you upon arrival.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),

        // Large Center Avatar Display
        Center(
          child: GestureDetector(
            onTap: _isUploadingProfilePhoto ? null : _showProfilePhotoSourcePicker,
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPhoto ? AppColors.primary : AppColors.border,
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    image: _profileImageFile != null
                        ? DecorationImage(
                            image: FileImage(_profileImageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(_profileImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: !hasPhoto
                      ? (_isUploadingProfilePhoto
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: AppColors.textDark,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 70,
                              color: AppColors.textDark,
                            ))
                      : null,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasPhoto ? const Color(0xFF16A34A) : AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasPhoto ? Icons.check_rounded : Icons.camera_alt_rounded,
                      size: 20,
                      color: hasPhoto ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Center(
          child: Text(
            hasPhoto ? 'Photo Uploaded Successfully ✓' : 'No photo uploaded yet',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: hasPhoto ? const Color(0xFF16A34A) : AppColors.textMuted,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Action Buttons (Selfie & Gallery)
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _isUploadingProfilePhoto ? null : () => _pickAndUploadProfilePhoto(ImageSource.camera),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: AppColors.textDark, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take Selfie',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Front Camera',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: _isUploadingProfilePhoto ? null : () => _pickAndUploadProfilePhoto(ImageSource.gallery),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library_rounded, color: AppColors.textDark, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gallery',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Photo Library',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Guidelines card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Photo Guidelines',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Face the camera directly with good lighting.\n• Do not wear sunglasses, masks, or hats.\n• Must be a clear and sharp portrait photo.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 3: Vehicle Information
  Widget _buildStep3Vehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter details about the vehicle you will use for passenger trips.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        _buildInputLabel('Vehicle Make & Model'),
        _buildTextField(
          controller: _vehicleModelController,
          hint: 'e.g. Toyota Prius, Mercedes E-Class',
          icon: Icons.directions_car_rounded,
        ),
        const SizedBox(height: 16),

        _buildInputLabel('License Plate Number'),
        _buildTextField(
          controller: _vehiclePlateController,
          hint: 'e.g. SK-1234-AB or PG-TX-789',
          icon: Icons.badge_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Manufacturing Year'),
                  _buildTextField(
                    controller: _carYearController,
                    hint: 'e.g. 2022',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Vehicle Color'),
                  _buildTextField(
                    controller: _vehicleColorController,
                    hint: 'e.g. White, Black',
                    icon: Icons.palette_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 4: Bank / Payout
  Widget _buildStep4Bank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payout & Bank Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your ride fares and tips will be transferred directly to this account.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        _buildInputLabel('Bank Name'),
        _buildTextField(
          controller: _bankNameController,
          hint: 'e.g. Stopanska Banka, NLB Banka',
          icon: Icons.account_balance_rounded,
        ),
        const SizedBox(height: 16),

        _buildInputLabel('Account Holder Name'),
        _buildTextField(
          controller: _accountHolderController,
          hint: 'Full legal name on bank account',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),

        _buildInputLabel('IBAN Number'),
        _buildTextField(
          controller: _ibanController,
          hint: _selectedCountry == 'MK'
              ? 'MK07 2000 0000 1234 56'
              : 'ME25 5300 0000 1234 5678',
          icon: Icons.credit_card_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        _buildInputLabel('SWIFT / BIC Code (Optional)'),
        _buildTextField(
          controller: _swiftController,
          hint: 'e.g. STBAMK2X or NLBMMEPG',
          icon: Icons.swap_horiz_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  // STEP 5: License & Document Photos
  Widget _buildStep5LicenseAndPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver License & Verification',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload clear scans or photos of your physical driver license for safety review.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        _buildInputLabel('Driver License Number'),
        _buildTextField(
          controller: _licenseNumberController,
          hint: 'e.g. DL-8921-482',
          icon: Icons.badge_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        _buildInputLabel('License Expiry Date'),
        GestureDetector(
          onTap: () => _selectDate(context, _licenseExpiryController),
          child: AbsorbPointer(
            child: _buildTextField(
              controller: _licenseExpiryController,
              hint: 'DD/MM/YYYY',
              icon: Icons.event_available_rounded,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Driver License Photos (Front & Back)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),

        // Front Photo Card
        _buildDocumentUploadCard(
          title: 'Front Side Photo',
          subtitle: 'Clear photo showing name, photo & license number',
          file: _frontImageFile,
          networkUrl: _frontLicenseUrl,
          isUploading: _isUploadingFront,
          onTap: () => _showImageSourcePicker(true),
        ),
        const SizedBox(height: 14),

        // Back Photo Card
        _buildDocumentUploadCard(
          title: 'Back Side Photo',
          subtitle: 'Clear photo showing vehicle categories & barcode',
          file: _backImageFile,
          networkUrl: _backLicenseUrl,
          isUploading: _isUploadingBack,
          onTap: () => _showImageSourcePicker(false),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required File? file,
    required String? networkUrl,
    required bool isUploading,
    required VoidCallback onTap,
  }) {
    final hasImage = file != null || (networkUrl != null && networkUrl.isNotEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasImage ? AppColors.primarySubtle : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasImage ? AppColors.primary : AppColors.border,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: hasImage ? AppColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textDark),
                      ),
                    )
                  : Icon(
                      hasImage ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                      color: AppColors.textDark,
                      size: 26,
                    ),
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
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUploading
                        ? 'Uploading to ID verifications...'
                        : (hasImage ? 'Photo attached & verified' : subtitle),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: hasImage ? const Color(0xFF16A34A) : AppColors.textMuted,
                      fontWeight: hasImage ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                hasImage ? 'Change' : 'Upload',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
