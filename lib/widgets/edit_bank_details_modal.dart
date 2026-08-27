import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class EditBankDetailsModal extends StatefulWidget {
  final String currentBankName;
  final String currentIban;
  final String currentSwift;
  final String currentAccountHolder;

  const EditBankDetailsModal({
    super.key,
    required this.currentBankName,
    required this.currentIban,
    required this.currentSwift,
    required this.currentAccountHolder,
  });

  /// Opens the edit bank modal. Returns true if bank details were updated.
  static Future<bool> show(
    BuildContext context, {
    required String currentBankName,
    required String currentIban,
    required String currentSwift,
    required String currentAccountHolder,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditBankDetailsModal(
        currentBankName: currentBankName,
        currentIban: currentIban,
        currentSwift: currentSwift,
        currentAccountHolder: currentAccountHolder,
      ),
    );
    return result ?? false;
  }

  @override
  State<EditBankDetailsModal> createState() => _EditBankDetailsModalState();
}

class _EditBankDetailsModalState extends State<EditBankDetailsModal> {
  late TextEditingController _bankNameController;
  late TextEditingController _ibanController;
  late TextEditingController _swiftController;
  late TextEditingController _holderController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(text: widget.currentBankName);
    _ibanController = TextEditingController(text: _formatIban(widget.currentIban));
    _swiftController = TextEditingController(text: widget.currentSwift.toUpperCase());
    _holderController = TextEditingController(text: widget.currentAccountHolder);
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    _holderController.dispose();
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

  void _onIbanChanged(String value) {
    final formatted = _formatIban(value);
    if (formatted != value) {
      _ibanController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _handleSave() async {
    final bankName = _bankNameController.text.trim();
    final ibanClean = _ibanController.text.replaceAll(' ', '').trim().toUpperCase();
    final swift = _swiftController.text.trim().toUpperCase();
    final holder = _holderController.text.trim();

    if (bankName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your bank name.');
      return;
    }

    if (ibanClean.length < 12) {
      setState(() => _errorMessage = 'Please enter a valid IBAN number.');
      return;
    }

    if (swift.isEmpty || swift.length < 6) {
      setState(() => _errorMessage = 'Please enter a valid SWIFT / BIC code.');
      return;
    }

    if (holder.isEmpty) {
      setState(() => _errorMessage = 'Please enter the account holder name.');
      return;
    }

    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _errorMessage = 'Driver session not found. Please log in.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🏦 [EditBankDetails] Saving bank details for driver $driverId...');

      await Supabase.instance.client.from('profiles').update({
        'bank_name': bankName,
        'iban': ibanClean,
        'swift_bic': swift,
        'account_holder_name': holder,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bank details updated successfully!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [EditBankDetails] Error saving: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save bank details. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom + 16;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bank & Payout Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
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
            const SizedBox(height: 14),

            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.textDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your payout earnings will be directly transferred to this bank account via SEPA / SWIFT transfer.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bank Name Field
            _buildFieldLabel('Bank Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _bankNameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'e.g. NLB Banka AD Podgorica',
                icon: Icons.business_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // Account Holder Name Field
            _buildFieldLabel('Account Holder Full Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'e.g. William Luther Berg',
                icon: Icons.person_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // IBAN Field
            _buildFieldLabel('IBAN Number'),
            const SizedBox(height: 6),
            TextField(
              controller: _ibanController,
              textCapitalization: TextCapitalization.characters,
              onChanged: _onIbanChanged,
              decoration: _inputDecoration(
                hint: 'e.g. ME25 5300 0000 1234 5678',
                icon: Icons.credit_card_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // SWIFT / BIC Field
            _buildFieldLabel('SWIFT / BIC Code'),
            const SizedBox(height: 6),
            TextField(
              controller: _swiftController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(
                hint: 'e.g. NLBMMEPG',
                icon: Icons.language_rounded,
              ),
            ),

            // Error Banner
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
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textDark,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, color: AppColors.textDark, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save Bank Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textInactive),
      prefixIcon: Icon(icon, color: AppColors.textDark, size: 19),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
