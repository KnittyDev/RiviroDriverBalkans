import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/withdraw_history_modal.dart';

class IbanPayoutSettingsScreen extends StatefulWidget {
  const IbanPayoutSettingsScreen({super.key});

  @override
  State<IbanPayoutSettingsScreen> createState() => _IbanPayoutSettingsScreenState();
}

class _IbanPayoutSettingsScreenState extends State<IbanPayoutSettingsScreen> {
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _ibanController = TextEditingController();
  final _swiftController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBankData();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    super.dispose();
  }

  String _formatIban(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  Future<void> _loadBankData() async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select('bank_name, iban, swift_bic, account_holder_name, full_name')
          .eq('id', driverId)
          .maybeSingle();

      if (profileRow != null && mounted) {
        final bName = profileRow['bank_name']?.toString() ?? '';
        _bankNameController.text = bName == 'NLB Banka AD Podgorica' ? '' : bName;

        _accountHolderController.text = profileRow['account_holder_name']?.toString() ??
            profileRow['full_name']?.toString() ??
            '';

        final bIban = profileRow['iban']?.toString() ?? '';
        _ibanController.text = bIban == 'ME255300000012345678' ? '' : _formatIban(bIban);

        final bSwift = profileRow['swift_bic']?.toString() ?? '';
        _swiftController.text = bSwift == 'NLBMMEPG' ? '' : bSwift.toUpperCase();
      }
    } catch (e) {
      debugPrint('⚠️ [IbanPayoutSettings] Error loading bank data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final bankName = _bankNameController.text.trim();
    final holder = _accountHolderController.text.trim();
    final ibanClean = _ibanController.text.replaceAll(' ', '').trim().toUpperCase();
    final swift = _swiftController.text.trim().toUpperCase();

    if (bankName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your bank name.');
      return;
    }
    if (holder.isEmpty) {
      setState(() => _errorMessage = 'Please enter account holder name.');
      return;
    }
    if (ibanClean.length < 12) {
      setState(() => _errorMessage = 'Please enter a valid IBAN number.');
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
        'bank_name': bankName,
        'account_holder_name': holder,
        'iban': ibanClean,
        'swift_bic': swift,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'IBAN & Payout details updated successfully!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ [IbanPayoutSettings] Error saving: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save bank details: $e';
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
          'IBAN & Payout Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: AppColors.textDark),
            tooltip: 'Payout History',
            onPressed: () => WithdrawHistoryModal.show(context, initialFilter: 'payouts'),
          ),
        ],
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
                    // Bank Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryActiveBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_rounded, color: AppColors.textDark, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Primary Payout Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Earnings are deposited directly to your verified bank IBAN.',
                                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    _buildTextField('Bank Name', _bankNameController, Icons.business_rounded, hint: 'e.g. NLB Banka AD Podgorica'),
                    const SizedBox(height: 16),
                    _buildTextField('Account Holder Name', _accountHolderController, Icons.person_rounded, hint: 'e.g. William Luther Berg'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'IBAN Number',
                      _ibanController,
                      Icons.credit_card_rounded,
                      hint: 'e.g. ME25 5300 0000 1234 5678',
                      onChanged: (val) {
                        final formatted = _formatIban(val);
                        if (formatted != val) {
                          _ibanController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('SWIFT / BIC Code', _swiftController, Icons.language_rounded, hint: 'e.g. NLBMMEPG'),
                    const SizedBox(height: 10),

                    if (_errorMessage != null) ...[
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
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 20),

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
                                'Save & Update Payout Account',
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
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
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
