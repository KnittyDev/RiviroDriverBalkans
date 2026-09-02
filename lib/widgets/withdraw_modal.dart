import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/driver_stats_service.dart';
import '../theme/app_theme.dart';
import 'edit_bank_details_modal.dart';
import 'withdraw_history_modal.dart';

class WithdrawModal extends StatefulWidget {
  final String availableBalance;

  const WithdrawModal({
    super.key,
    this.availableBalance = '0.00€',
  });

  static void show(BuildContext context, {String availableBalance = '0.00€'}) {
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
  bool _isLoadingProfile = true;
  String? _errorMessage;

  String _bankName = 'NLB Banka AD Podgorica';
  String _iban = 'ME255300000012345678';
  String _swiftBic = 'NLBMMEPG';
  String _holderName = 'Driver';
  double _currentWallet = 0.0;
  String? _lastPayoutRef;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0.00');
    _fetchLiveDriverBankData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveDriverBankData() async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select('bank_name, iban, swift_bic, account_holder_name, full_name, driver_wallet')
          .eq('id', driverId)
          .maybeSingle();

      if (profileRow != null) {
        final walletVal = (profileRow['driver_wallet'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          _bankName = profileRow['bank_name']?.toString() ?? 'NLB Banka AD Podgorica';
          _iban = profileRow['iban']?.toString() ?? 'ME255300000012345678';
          _swiftBic = profileRow['swift_bic']?.toString() ?? 'NLBMMEPG';
          _holderName = profileRow['account_holder_name']?.toString() ??
              profileRow['full_name']?.toString() ??
              'Driver';
          _currentWallet = walletVal > 0 ? walletVal : 0.0;
          _amountController.text = _currentWallet > 0 ? _currentWallet.toStringAsFixed(2) : '0.00';
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('⚠️ [WithdrawModal] Error fetching bank data: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  String _formatMaskedIban(String iban) {
    final clean = iban.replaceAll(' ', '');
    if (clean.length < 8) return iban;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix •••• •••• $suffix';
  }

  void _handleConfirmPayout() async {
    final enteredAmount = double.tryParse(_amountController.text.trim());
    if (enteredAmount == null || enteredAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid withdrawal amount.');
      return;
    }

    if (enteredAmount > _currentWallet) {
      setState(() => _errorMessage =
          'Withdrawal amount exceeds available balance (€${_currentWallet.toStringAsFixed(2)}).');
      return;
    }

    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      setState(() => _errorMessage = 'Driver session not found.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      final updatedWallet = _currentWallet - enteredAmount;
      final payoutRef = '#TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-${_isExpressPayout ? 'SEPA' : 'STD'}';

      // 1. Deduct wallet in profiles
      await Supabase.instance.client.from('profiles').update({
        'driver_wallet': updatedWallet,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      // 2. Insert into wallet_transactions
      await Supabase.instance.client.from('wallet_transactions').insert({
        'user_id': driverId,
        'type': 'withdraw',
        'amount': -enteredAmount,
        'currency': '€',
        'title': 'Payout Withdrawal',
        'subtitle': 'To $_bankName (${_formatMaskedIban(_iban)}) • $payoutRef',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. Refresh live driver stats
      await DriverStatsService.fetchDriverLiveStats(driverId);

      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _currentWallet = updatedWallet;
          _lastPayoutRef = payoutRef;
        });
      }
    } catch (e) {
      debugPrint('❌ [WithdrawModal] Payout error: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Payout request failed: $e';
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

        // Header Title & History Action
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
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    WithdrawHistoryModal.show(context);
                  },
                  icon: const Icon(Icons.history_rounded, color: AppColors.textDark),
                  tooltip: 'Withdrawal History',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Destination Bank Account Card (With Change/Edit button)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
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
                          _bankName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'IBAN: ${_formatMaskedIban(_iban)}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_swiftBic.isNotEmpty)
                          Text(
                            'SWIFT: $_swiftBic • Holder: $_holderName',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textInactive),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
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
            ],
          ),
        ),
        const SizedBox(height: 16),

        Builder(builder: (context) {
          final stats = DriverStatsService.statsNotifier.value;
          final symbol = stats.currencySymbol;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Withdrawal Amount ($symbol)',
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  Text(
                    'Available: ${stats.formatCurrency(_currentWallet)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentWallet > 0 ? const Color(0xFF16A34A) : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Amount Input Field
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                    child: Text(
                      symbol,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textMuted.withValues(alpha: 0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Preset Quick Choice Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPresetChip(stats.formatCurrency(stats.accountCountry == 'MK' ? 1000 : 25), stats.accountCountry == 'MK' ? '1000.00' : '25.00'),
                  _buildPresetChip(stats.formatCurrency(stats.accountCountry == 'MK' ? 2500 : 50), stats.accountCountry == 'MK' ? '2500.00' : '50.00'),
                  _buildPresetChip(stats.formatCurrency(stats.accountCountry == 'MK' ? 5000 : 100), stats.accountCountry == 'MK' ? '5000.00' : '100.00'),
                  _buildPresetChip('Max (${stats.formatCurrency(_currentWallet)})', _currentWallet.toStringAsFixed(2)),
                ],
              ),
            ],
          );
        }),
        const SizedBox(height: 16),

        // Payout Method Speed Selection
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isExpressPayout ? Icons.bolt_rounded : Icons.account_balance_rounded,
                    color: _isExpressPayout ? const Color(0xFFEAB308) : AppColors.textDark,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isExpressPayout ? 'SEPA Instant Transfer' : 'Standard Bank Transfer',
                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        _isExpressPayout ? 'Estimated arrival: 5-15 minutes' : 'Estimated arrival: 1-2 business days',
                        style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isExpressPayout,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _isExpressPayout = val),
              ),
            ],
          ),
        ),

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
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

        const SizedBox(height: 18),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isProcessing || _currentWallet <= 0 ? null : _handleConfirmPayout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
              disabledBackgroundColor: Colors.grey.shade200,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.textDark),
                  )
                : Text(
                    'Confirm Payout (€${_amountController.text})',
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, String value) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _amountController.text = value;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 44),
        ),
        const SizedBox(height: 16),
        Text(
          'Payout Initiated!',
          style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        Text(
          'Your payout of €${_amountController.text} has been successfully sent to your bank account.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildSuccessRow('Destination Bank', _bankName),
              const Divider(color: AppColors.border, height: 16),
              _buildSuccessRow('IBAN', _formatMaskedIban(_iban)),
              const Divider(color: AppColors.border, height: 16),
              _buildSuccessRow('Estimated Arrival', _isExpressPayout ? '5-15 min (SEPA Instant)' : '1-2 business days'),
              const Divider(color: AppColors.border, height: 16),
              _buildSuccessRow('Transaction Ref', _lastPayoutRef ?? '#TRX-SEPA-9821'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
        Text(value, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ],
    );
  }
}
