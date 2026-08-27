import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/driver_stats_service.dart';
import '../services/stripe_service.dart';
import '../theme/app_theme.dart';
import 'payment_success_modal.dart';

class SettleDebtModal extends StatefulWidget {
  final double currentDebt; // negative number, e.g. -14.60

  const SettleDebtModal({
    super.key,
    required this.currentDebt,
  });

  /// Opens the Stripe Debt Settlement modal. Returns true if payment succeeded.
  static Future<bool> show(
    BuildContext context, {
    required double currentDebt,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettleDebtModal(currentDebt: currentDebt),
    );
    return result ?? false;
  }

  @override
  State<SettleDebtModal> createState() => _SettleDebtModalState();
}

class _SettleDebtModalState extends State<SettleDebtModal> {
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();

  double _selectedAmount = 10.0;
  bool _isCustomAmount = false;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final double fullDebt = widget.currentDebt.abs();
    _selectedAmount = fullDebt > 0 ? fullDebt : 10.0;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  IconData _getCardIcon(String number) {
    final clean = number.replaceAll(' ', '');
    if (clean.startsWith('4')) {
      return Icons.credit_card_rounded; // Visa
    } else if (clean.startsWith('51') ||
        clean.startsWith('52') ||
        clean.startsWith('53') ||
        clean.startsWith('54') ||
        clean.startsWith('55')) {
      return Icons.credit_card_rounded; // Mastercard
    } else if (clean.startsWith('34') || clean.startsWith('37')) {
      return Icons.credit_card_rounded; // Amex
    }
    return Icons.credit_card_rounded;
  }

  void _formatCardNumber(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(clean[i]);
    }
    final formatted = buffer.toString();
    if (formatted != value) {
      _cardNumberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _formatExpiry(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 2) {
      final formatted = '${clean.substring(0, 2)}/${clean.substring(2, clean.length.clamp(2, 4))}';
      if (formatted != value) {
        _expiryController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  Future<void> _handlePayment() async {
    final cleanCard = _cardNumberController.text.replaceAll(' ', '').trim();
    final expiry = _expiryController.text.trim();
    final cvc = _cvcController.text.trim();
    final name = _nameController.text.trim();

    // Validations
    if (cleanCard.length < 15) {
      setState(() => _errorMessage = 'Please enter a valid 16-digit card number.');
      return;
    }

    if (!expiry.contains('/') || expiry.length < 5) {
      setState(() => _errorMessage = 'Please enter a valid expiry date (MM/YY).');
      return;
    }

    final parts = expiry.split('/');
    final expMonth = parts[0];
    final expYear = '20${parts[1]}';

    final int? m = int.tryParse(expMonth);
    if (m == null || m < 1 || m > 12) {
      setState(() => _errorMessage = 'Invalid expiry month.');
      return;
    }

    if (cvc.length < 3) {
      setState(() => _errorMessage = 'Please enter a valid 3 or 4-digit CVC.');
      return;
    }

    double payAmount = _selectedAmount;
    if (_isCustomAmount) {
      final parsed = double.tryParse(_customAmountController.text.trim());
      if (parsed == null || parsed <= 0) {
        setState(() => _errorMessage = 'Please enter a valid payment amount.');
        return;
      }
      payAmount = parsed;
    }

    final driverId = AuthService.currentDriverNotifier.value?.id;
    if (driverId == null || driverId.isEmpty) {
      setState(() => _errorMessage = 'Driver session not found. Please re-login.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    final result = await StripeService.processDebtSettlement(
      driverId: driverId,
      amount: payAmount,
      cardNumber: cleanCard,
      expMonth: expMonth,
      expYear: expYear,
      cvc: cvc,
      cardHolderName: name.isNotEmpty ? name : 'Rivilo Driver',
    );

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context, true);
        PaymentSuccessModal.show(
          context,
          amountPaid: payAmount,
          last4: cleanCard.length >= 4 ? cleanCard.substring(cleanCard.length - 4) : '4242',
          transactionId: result.paymentIntentId,
        );
      }
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isProcessing = false;
        _errorMessage = result.errorMessage ?? 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom + 14;
    final double fullDebt = widget.currentDebt.abs();

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
            // Drag handle
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
            const SizedBox(height: 14),

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
                    Icons.credit_card_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Settle Commission Debt',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 12),

            // Debt Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outstanding Debt',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '-${fullDebt.toStringAsFixed(2)}€',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ValueListenableBuilder<double>(
                      valueListenable: DriverStatsService.debtLimitNotifier,
                      builder: (context, debtLimit, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Limit',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '-${debtLimit.abs().toStringAsFixed(2)}€',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
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
            const SizedBox(height: 16),

            // Amount Selector Pills
            Text(
              'Select Amount to Pay',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAmountPill(
                    label: 'Full (${fullDebt.toStringAsFixed(2)}€)',
                    amount: fullDebt,
                    isSelected: !_isCustomAmount && _selectedAmount == fullDebt,
                  ),
                  _buildAmountPill(
                    label: '10.00€',
                    amount: 10.0,
                    isSelected: !_isCustomAmount && _selectedAmount == 10.0,
                  ),
                  _buildAmountPill(
                    label: '20.00€',
                    amount: 20.0,
                    isSelected: !_isCustomAmount && _selectedAmount == 20.0,
                  ),
                  _buildAmountPill(
                    label: 'Custom',
                    amount: 0.0,
                    isSelected: _isCustomAmount,
                    isCustom: true,
                  ),
                ],
              ),
            ),

            if (_isCustomAmount) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Custom Amount (€)',
                  labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                  prefixText: '€ ',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Card Input Fields
            Text(
              'Card Details',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            // Card Number
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              onChanged: _formatCardNumber,
              decoration: InputDecoration(
                hintText: '4242 •••• •••• 4242',
                hintStyle: GoogleFonts.spaceMono(fontSize: 13.5, color: AppColors.textInactive),
                prefixIcon: const Icon(Icons.credit_card_rounded, color: AppColors.textDark, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Expiry & CVC in Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: _formatExpiry,
                    decoration: InputDecoration(
                      hintText: 'MM/YY',
                      hintStyle: GoogleFonts.spaceMono(fontSize: 13, color: AppColors.textInactive),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textDark, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cvcController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      hintText: 'CVC',
                      hintStyle: GoogleFonts.spaceMono(fontSize: 13, color: AppColors.textInactive),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDark, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Cardholder Name
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Cardholder Name (Optional)',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textInactive),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textDark, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
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

            const SizedBox(height: 18),

            // Submit Payment Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing || _isSuccess ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSuccess ? const Color(0xFF22C55E) : AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textDark,
                        ),
                      )
                    : _isSuccess
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Payment Successful!',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, color: AppColors.textDark, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Pay €${(_isCustomAmount ? (double.tryParse(_customAmountController.text) ?? 0.0) : _selectedAmount).toStringAsFixed(2)} via Stripe',
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
            const SizedBox(height: 10),

            // Security note
            Center(
              child: Text(
                '🔒 Payments are encrypted and securely processed by Stripe.',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountPill({
    required String label,
    required double amount,
    required bool isSelected,
    bool isCustom = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isCustomAmount = isCustom;
          if (!isCustom) {
            _selectedAmount = amount;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.textDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
