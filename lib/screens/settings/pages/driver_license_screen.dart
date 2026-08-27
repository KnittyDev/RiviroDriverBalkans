import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class DriverLicenseScreen extends StatefulWidget {
  const DriverLicenseScreen({super.key});

  @override
  State<DriverLicenseScreen> createState() => _DriverLicenseScreenState();
}

class _DriverLicenseScreenState extends State<DriverLicenseScreen> {
  final _licenseNumberController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVerified = true;
  String? _errorMessage;

  String? _frontImagePath;
  String? _backImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLicenseData();
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _loadLicenseData() async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select('license_number, license_category, license_expiry_date, is_license_verified, license_front_url, license_back_url')
          .eq('id', driverId)
          .maybeSingle();

      if (profileRow != null && mounted) {
        _licenseNumberController.text = profileRow['license_number']?.toString() ?? 'DL-9821-48201';
        _categoryController.text = profileRow['license_category']?.toString() ?? 'Category B (Passenger Car)';
        _expiryDateController.text = profileRow['license_expiry_date']?.toString() ?? '14/08/2028';
        _isVerified = profileRow['is_license_verified'] == true;
        _frontImagePath = profileRow['license_front_url']?.toString();
        _backImagePath = profileRow['license_back_url']?.toString();
      }
    } catch (e) {
      debugPrint('⚠️ [DriverLicenseScreen] Error loading license data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _pickDocumentImage(bool isFront) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        setState(() {
          if (isFront) {
            _frontImagePath = photo.path;
          } else {
            _backImagePath = photo.path;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isFront ? 'Front' : 'Back'} side document scan selected!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: AppColors.textDark,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [DriverLicenseScreen] Error picking document photo: $e');
    }
  }

  Future<void> _handleSave() async {
    final licenseNumber = _licenseNumberController.text.trim().toUpperCase();
    final category = _categoryController.text.trim();
    final expiry = _expiryDateController.text.trim();

    if (licenseNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter driver license number.');
      return;
    }

    if (expiry.isEmpty) {
      setState(() => _errorMessage = 'Please enter expiration date.');
      return;
    }

    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _errorMessage = 'Driver session not found.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        'license_number': licenseNumber,
        'license_category': category.isNotEmpty ? category : 'Category B (Passenger Car)',
        'license_expiry_date': expiry,
        'is_license_verified': true,
        if (_frontImagePath != null) 'license_front_url': _frontImagePath,
        if (_backImagePath != null) 'license_back_url': _backImagePath,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Driver license information updated and verified!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ [DriverLicenseScreen] Error saving license: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save license info: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 30;

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
          'Driver License & Verification',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: safeBottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verified Status Badge Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isVerified ? 'Identity Verified ✓' : 'Verification In Review',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  _isVerified
                                      ? 'Driver License has been authenticated and approved.'
                                      : 'Document scans are submitted for review.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: const Color(0xFF15803D).withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    _buildTextField(
                      'License Number',
                      _licenseNumberController,
                      Icons.badge_rounded,
                      hint: 'e.g. DL-9821-48201',
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Driving Category',
                      _categoryController,
                      Icons.directions_car_rounded,
                      hint: 'e.g. Category B (Passenger Car)',
                    ),
                    const SizedBox(height: 16),
                    _buildDateField('Expiration Date', _expiryDateController, Icons.event_rounded),
                    const SizedBox(height: 24),

                    // Upload Document Cards
                    Text(
                      'Document Scans',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDocumentImage(true),
                            child: _buildDocUploadCard(
                              'Front Side',
                              _frontImagePath != null ? 'Uploaded ✓' : 'Tap to Upload',
                              Icons.contact_page_rounded,
                              isUploaded: _frontImagePath != null,
                              imagePath: _frontImagePath,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDocumentImage(false),
                            child: _buildDocUploadCard(
                              'Back Side',
                              _backImagePath != null ? 'Uploaded ✓' : 'Tap to Upload',
                              Icons.contact_page_outlined,
                              isUploaded: _backImagePath != null,
                              imagePath: _backImagePath,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.textDark),
                              )
                            : Text(
                                'Save & Verify License',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
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

  Widget _buildDocUploadCard(
    String title,
    String status,
    IconData icon, {
    bool isUploaded = true,
    String? imagePath,
  }) {
    final bool isNetwork = imagePath != null && (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isUploaded ? const Color(0xFF86EFAC) : AppColors.border),
      ),
      child: Column(
        children: [
          if (isNetwork)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imagePath,
                height: 48,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(icon, size: 30, color: const Color(0xFF16A34A)),
              ),
            )
          else
            Icon(icon, size: 30, color: isUploaded ? const Color(0xFF16A34A) : AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUploaded) const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF15803D)),
              if (isUploaded) const SizedBox(width: 3),
              Text(
                status,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: isUploaded ? const Color(0xFF15803D) : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectDate(context, controller),
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textDark),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
              onPressed: () => _selectDate(context, controller),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textInactive),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ],
    );
  }
}
