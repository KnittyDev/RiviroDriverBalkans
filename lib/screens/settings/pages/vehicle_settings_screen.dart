import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_stats_service.dart';
import '../../../theme/app_theme.dart';

class VehicleSettingsScreen extends StatefulWidget {
  const VehicleSettingsScreen({super.key});

  @override
  State<VehicleSettingsScreen> createState() => _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState extends State<VehicleSettingsScreen> {
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleData() async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select('vehicle_model, vehicle_plate, car_year, vehicle_color')
          .eq('id', driverId)
          .maybeSingle();

      if (profileRow != null && mounted) {
        _modelController.text = profileRow['vehicle_model']?.toString() ?? 'Mercedes-Benz E-Class';
        _plateController.text = profileRow['vehicle_plate']?.toString() ?? 'PG-TX-789';
        _yearController.text = profileRow['car_year']?.toString() ?? '2022';
        _colorController.text = profileRow['vehicle_color']?.toString() ?? 'Black Metallic';
      }
    } catch (e) {
      debugPrint('⚠️ [VehicleSettings] Error loading vehicle data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final model = _modelController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();
    final year = _yearController.text.trim();
    final color = _colorController.text.trim();

    if (model.isEmpty) {
      setState(() => _errorMessage = 'Please enter vehicle make and model.');
      return;
    }

    if (plate.isEmpty) {
      setState(() => _errorMessage = 'Please enter license plate number.');
      return;
    }

    if (year.isEmpty) {
      setState(() => _errorMessage = 'Please enter manufacturing year.');
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
        'vehicle_model': model,
        'vehicle_plate': plate,
        'car_year': year,
        'vehicle_color': color.isNotEmpty ? color : 'Black Metallic',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      // Refresh Driver Live Stats so Profile & Dashboard show updated car
      await DriverStatsService.fetchDriverLiveStats(driverId);

      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle settings saved successfully!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ [VehicleSettings] Error saving vehicle details: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save vehicle details: $e';
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
          'Vehicle Settings',
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
                    // Status Card (Approved by Rivilo)
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
                                  'Approved by Rivilo ✓',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  'Active Registered Vehicle for Passenger Trips',
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
                      'Vehicle Make & Model',
                      _modelController,
                      Icons.directions_car_rounded,
                      hint: 'e.g. Mercedes-Benz E-Class',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'License Plate Number',
                      _plateController,
                      Icons.pin_rounded,
                      hint: 'e.g. PG-TX-789',
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Manufacturing Year (car_year)',
                      _yearController,
                      Icons.calendar_today_rounded,
                      hint: 'e.g. 2022',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Vehicle Color',
                      _colorController,
                      Icons.palette_rounded,
                      hint: 'e.g. Black Metallic',
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
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
                                'Save Vehicle Details',
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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
