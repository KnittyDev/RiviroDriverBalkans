import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'withdraw_history_modal.dart';

class WithdrawModal extends StatefulWidget {
  final String availableBalance;

  const WithdrawModal({
    super.key,
    this.availableBalance = '1.245€',
  });

  static void show(BuildContext context, {String availableBalance = '1.245€'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawModal(availableBalance: availableBalance),
    );
  }

  @override
  State<WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<WithdrawModal> {
  late TextEditingController _amountController;
  bool _isExpressPayout = true;
  bool _isProcessing = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1245.00');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleConfirmPayout() async {
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 1400));

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset + safeBottomInset,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      key: const ValueKey('form_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle Bar
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

        // Header Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryActiveBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.textDark, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Withdraw Balance',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Destination Bank Account Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PKO Bank Polski',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'IBAN: PL89 1020 **** **** 4821',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Verified',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Amount Input Field
        Text(
          'Withdrawal Amount (€)',
          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
              child: Text(
                '€',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
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
        const SizedBox(height: 10),

        // Preset Quick Choice Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPresetChip('100€', '100.00'),
            _buildPresetChip('250€', '250.00'),
            _buildPresetChip('500€', '500.00'),
            _buildPresetChip('Max (${widget.availableBalance})', '1245.00'),
          ],
        ),
        const SizedBox(height: 16),

        const SizedBox(height: 22),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleConfirmPayout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirm Withdrawal',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Withdrawal History Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              WithdrawHistoryModal.show(context);
            },
            icon: const Icon(Icons.history_rounded, color: AppColors.textDark, size: 20),
            label: Text(
              'Withdrawal History',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountController.text = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'Withdrawal Initiated!',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '€${_amountController.text} is on its way to your PKO Bank Polski IBAN.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Ref ID: #TRX-9821-SEPA',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
