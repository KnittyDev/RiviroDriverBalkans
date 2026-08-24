import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

enum UserRole { driver, rider, admin }

class RoleSelectorCard extends StatefulWidget {
  final String initialRole;
  final String? driverId;

  const RoleSelectorCard({
    super.key,
    this.initialRole = 'driver',
    this.driverId,
  });

  @override
  State<RoleSelectorCard> createState() => _RoleSelectorCardState();
}

class _RoleSelectorCardState extends State<RoleSelectorCard> {
  late String _selectedRole;
  bool _isSyncing = false;

  String get _activeDriverId =>
      widget.driverId ?? AuthService.currentDriverNotifier.value?.id ?? '';

  String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://dpxthqrofxsciaqbmnoq.supabase.co';
  String get _supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHRocXJvZnhzY2lhcWJtbm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MjQ3OTAsImV4cCI6MjEwMTMwMDc5MH0.cVjaM5oAxinicaal1BV9D0Qa1JbJolAE5doKjsYH3kA';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole.toLowerCase();
  }

  Future<void> _updateRoleInSupabase(String roleValue) async {
    setState(() {
      _selectedRole = roleValue;
      _isSyncing = true;
    });

    try {
      final endpoint = '$_supabaseUrl/rest/v1/profiles?id=eq.$_activeDriverId';
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'role': roleValue,
          'updated_at': nowUtcIso,
        }),
      );

      if (response.statusCode >= 400) {
        // Upsert fallback
        await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/profiles'),
          headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $_supabaseAnonKey',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode({
            'id': _activeDriverId,
            'full_name': AuthService.currentDriverNotifier.value?.fullName ?? 'Driver',
            'role': roleValue,
            'updated_at': nowUtcIso,
          }),
        );
      }

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account role updated to ${roleValue.toUpperCase()} (Synced to Supabase)!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating role in Supabase: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryActiveBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, color: AppColors.textDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Profile Account Role',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              if (_isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Supabase Role',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-Role Segmented Selector Chips (Driver, Rider, Admin)
          Row(
            children: [
              // 1. Driver Role Button
              Expanded(
                child: _buildRoleChip(
                  roleKey: 'driver',
                  label: 'Driver',
                  icon: Icons.directions_car_rounded,
                  activeColor: AppColors.primary,
                  activeTextColor: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),

              // 2. Rider Role Button
              Expanded(
                child: _buildRoleChip(
                  roleKey: 'rider',
                  label: 'Rider',
                  icon: Icons.person_pin_circle_rounded,
                  activeColor: const Color(0xFF3B82F6),
                  activeTextColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Admin Role Button
              Expanded(
                child: _buildRoleChip(
                  roleKey: 'admin',
                  label: 'Admin',
                  icon: Icons.shield_rounded,
                  activeColor: const Color(0xFFF59E0B),
                  activeTextColor: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip({
    required String roleKey,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeTextColor,
  }) {
    final isSelected = _selectedRole == roleKey;

    return GestureDetector(
      onTap: () => _updateRoleInSupabase(roleKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeTextColor : AppColors.textDark,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeTextColor : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
