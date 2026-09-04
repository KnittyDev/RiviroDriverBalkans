import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/driver_stats_service.dart';
import '../theme/app_theme.dart';

typedef DriverTransactionsModal = WithdrawHistoryModal;

class WithdrawHistoryModal extends StatefulWidget {
  final String initialFilter; // 'all', 'earnings', 'payouts', 'commissions'

  const WithdrawHistoryModal({
    super.key,
    this.initialFilter = 'all',
  });

  static void show(BuildContext context, {String initialFilter = 'all'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawHistoryModal(initialFilter: initialFilter),
    );
  }

  @override
  State<WithdrawHistoryModal> createState() => _WithdrawHistoryModalState();
}

class _WithdrawHistoryModalState extends State<WithdrawHistoryModal> {
  late String _selectedFilter;
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;

  double _totalEarned = 0.0;
  double _totalPayouts = 0.0;
  String _currencySymbol = '€';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _fetchFullFinancialHistory();
  }

  Future<void> _fetchFullFinancialHistory() async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final stats = DriverStatsService.statsNotifier.value;
      _currencySymbol = stats.currencySymbol.isNotEmpty ? stats.currencySymbol : '€';

      // 1. Fetch wallet_transactions
      final txRows = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', driverId)
          .order('created_at', ascending: false)
          .limit(40);

      // 2. Fetch payout_requests
      final payoutRows = await Supabase.instance.client
          .from('payout_requests')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(30);

      // 3. Fetch completed rides for backup/rich context
      final rideRows = await Supabase.instance.client
          .from('rides')
          .select('id, fare_amount, driver_payout_amount, payment_method, status, created_at, pickup_address, destination_address')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(30);

      final List<Map<String, dynamic>> combined = [];
      final Set<String> processedRideIds = {};
      final Set<String> processedPayoutRefs = {};

      double earnedAcc = 0.0;
      double payoutAcc = 0.0;

      // A. Process Payout Requests
      for (final p in payoutRows) {
        final rawAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final ref = p['payout_reference']?.toString() ?? '';
        final status = p['status']?.toString().toLowerCase() ?? 'pending';
        final bank = p['bank_name']?.toString() ?? 'Bank Account';
        final iban = p['iban']?.toString() ?? '';
        final isExpress = p['is_express'] == true;
        final maskedIban = iban.length >= 8
            ? '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 4)}'
            : iban;

        if (ref.isNotEmpty) processedPayoutRefs.add(ref);
        payoutAcc += rawAmount;

        combined.add({
          'id': p['id']?.toString() ?? UniqueKey().toString(),
          'category': 'payout',
          'type': 'withdraw',
          'amount': -rawAmount,
          'title': isExpress ? 'Express Payout' : 'Payout Request',
          'subtitle': 'To $bank ($maskedIban) • $ref',
          'status': status,
          'created_at': p['created_at'],
          'rejection_reason': p['rejection_reason'],
        });
      }

      // B. Process Wallet Transactions
      for (final tx in txRows) {
        final rawAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = tx['type']?.toString().toLowerCase() ?? '';
        final title = tx['title']?.toString() ?? 'Transaction';
        final subtitle = tx['subtitle']?.toString() ?? '';
        final rideId = tx['ride_id']?.toString();
        final txStatus = tx['status']?.toString().toLowerCase() ?? 'completed';

        if (rideId != null && rideId.isNotEmpty) {
          processedRideIds.add(rideId);
        }

        // If this is a withdraw transaction already covered by payout_requests, skip duplicate
        if (type == 'withdraw') {
          bool alreadyCovered = false;
          for (final ref in processedPayoutRefs) {
            if (subtitle.contains(ref)) {
              alreadyCovered = true;
              break;
            }
          }
          if (alreadyCovered) continue;
        }

        String category = 'other';
        if (type == 'withdraw') {
          category = 'payout';
          payoutAcc += rawAmount.abs();
        } else if (type == 'trip_earning' || (rawAmount > 0 && type != 'deposit')) {
          category = 'earning';
          earnedAcc += rawAmount;
        } else if (type == 'commission_deduction') {
          category = 'commission';
        } else if (type == 'deposit') {
          category = 'deposit';
        }

        combined.add({
          'id': tx['id']?.toString() ?? UniqueKey().toString(),
          'category': category,
          'type': type,
          'amount': rawAmount,
          'title': title,
          'subtitle': subtitle,
          'status': txStatus,
          'created_at': tx['created_at'],
        });
      }

      // C. Process Completed Rides (Fill in any ride earnings not logged in wallet_transactions)
      for (final r in rideRows) {
        final rId = r['id']?.toString() ?? '';
        if (processedRideIds.contains(rId)) continue;

        final fare = (r['fare_amount'] as num?)?.toDouble() ??
            double.tryParse(r['fare_amount']?.toString() ?? '0') ??
            0.0;
        final driverPayout = (r['driver_payout_amount'] as num?)?.toDouble() ??
            double.tryParse(r['driver_payout_amount']?.toString() ?? '0') ??
            (fare * 0.85); // 85% driver share
        final payMethod = r['payment_method']?.toString() ?? 'Cash';
        final isCash = payMethod.toLowerCase().contains('cash');
        final shortTripId = rId.length >= 4 ? '#TR-${rId.substring(0, 4).toUpperCase()}' : '#TR-0000';

        if (!isCash && driverPayout > 0) {
          earnedAcc += driverPayout;
          combined.add({
            'id': rId,
            'category': 'earning',
            'type': 'trip_earning',
            'amount': driverPayout,
            'title': 'Trip Earnings ($shortTripId)',
            'subtitle': '$payMethod Payment • Completed',
            'status': 'completed',
            'created_at': r['created_at'],
          });
        }
      }

      // Sort all chronologically descending
      combined.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _allTransactions = combined;
          _totalEarned = earnedAcc;
          _totalPayouts = payoutAcc;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('⚠️ [WithdrawHistoryModal] Error loading transactions: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'all') return _allTransactions;
    if (_selectedFilter == 'earnings') {
      return _allTransactions.where((t) => t['category'] == 'earning').toList();
    }
    if (_selectedFilter == 'payouts') {
      return _allTransactions.where((t) => t['category'] == 'payout').toList();
    }
    if (_selectedFilter == 'commissions') {
      return _allTransactions.where((t) => t['category'] == 'commission').toList();
    }
    return _allTransactions;
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Recent';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 24;
    final currentStats = DriverStatsService.statsNotifier.value;
    final currentBalanceStr = currentStats.formatCurrency(currentStats.totalBalance);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: safeBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Handle Bar
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

          // 2. Header Title & Close Button
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
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.textDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Earnings, payouts & transactions',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Summary Stats Banner (Current Balance & Payouts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Available Balance',
                    value: currentBalanceStr,
                    valueColor: currentBalanceStr.startsWith('-') ? const Color(0xFFDC2626) : AppColors.textDark,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.primary,
                  ),
                ),
                Container(height: 32, width: 1, color: AppColors.border),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Payouts',
                    value: '$_currencySymbol${_totalPayouts.toStringAsFixed(2)}',
                    valueColor: const Color(0xFFD97706),
                    icon: Icons.hourglass_top_rounded,
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Filter Chips (All, Earnings, Payouts, Commissions)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Activity', _allTransactions.length),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'earnings',
                  'Fares & Tips',
                  _allTransactions.where((t) => t['category'] == 'earning').length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'payouts',
                  'Payouts',
                  _allTransactions.where((t) => t['category'] == 'payout').length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'commissions',
                  'Commissions',
                  _allTransactions.where((t) => t['category'] == 'commission').length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Transactions List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          else if (_filteredTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 44, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'No transactions found',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activity matching this filter will appear here.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: RefreshIndicator(
                onRefresh: _fetchFullFinancialHistory,
                color: AppColors.textDark,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  shrinkWrap: true,
                  itemCount: _filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final item = _filteredTransactions[index];
                    return _buildTransactionCard(item);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, int count) {
    final isSelected = _selectedFilter == key;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.textDark : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCleanTitle(String rawTitle) {
    final lower = rawTitle.toLowerCase();
    if (lower.contains('express payout')) return 'Express Payout';
    if (lower.contains('payout request')) return 'Payout Request';
    if (lower.contains('commission deduction')) return 'Trip Commission';
    if (lower.contains('trip earnings')) return 'Trip Earnings';
    if (lower.contains('admin balance top-up')) return 'Admin Top-up';
    if (lower.contains('debt balance settlement')) return 'Debt Settlement';
    return rawTitle;
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final rawAmount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final isPositive = rawAmount > 0;
    final amountSign = isPositive ? '+' : '-';
    final amountStr = '$amountSign$_currencySymbol${rawAmount.abs().toStringAsFixed(2)}';

    final category = item['category']?.toString() ?? 'other';
    final status = item['status']?.toString().toLowerCase() ?? 'completed';
    final isPending = status == 'pending';
    final isProcessing = status == 'processing' || status == 'in_progress' || status == 'on_the_way';
    final isRejected = status == 'rejected' || status == 'cancelled';

    final rawTitle = item['title']?.toString() ?? 'Transaction';
    final title = _formatCleanTitle(rawTitle);
    final subtitle = item['subtitle']?.toString() ?? '';
    final date = _formatDate(item['created_at']);

    // Visual styles per category
    Color iconBg;
    Color iconFg;
    IconData iconData;

    if (category == 'payout') {
      if (isPending) {
        iconBg = const Color(0xFFFEF3C7);
        iconFg = const Color(0xFFD97706);
        iconData = Icons.hourglass_top_rounded;
      } else if (isProcessing) {
        iconBg = const Color(0xFFE0F2FE);
        iconFg = const Color(0xFF0284C7);
        iconData = Icons.near_me_rounded;
      } else if (isRejected) {
        iconBg = const Color(0xFFFEE2E2);
        iconFg = const Color(0xFFDC2626);
        iconData = Icons.close_rounded;
      } else {
        iconBg = const Color(0xFFDCFCE7);
        iconFg = const Color(0xFF16A34A);
        iconData = Icons.arrow_upward_rounded;
      }
    } else if (category == 'earning') {
      iconBg = const Color(0xFFDCFCE7);
      iconFg = const Color(0xFF15803D);
      iconData = Icons.local_taxi_rounded;
    } else if (category == 'commission') {
      iconBg = const Color(0xFFF1F5F9);
      iconFg = const Color(0xFF64748B);
      iconData = Icons.percent_rounded;
    } else if (category == 'deposit') {
      iconBg = const Color(0xFFE0F2FE);
      iconFg = const Color(0xFF0284C7);
      iconData = Icons.credit_card_rounded;
    } else {
      iconBg = const Color(0xFFF1F5F9);
      iconFg = AppColors.textDark;
      iconData = Icons.swap_horiz_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(9.5),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconFg, size: 19),
          ),
          const SizedBox(width: 11),

          // Title, Subtitle, Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.poppins(fontSize: 9.5, color: AppColors.textInactive),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount & Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? const Color(0xFF16A34A) : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              if (category == 'payout') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPending
                        ? const Color(0xFFFEF3C7)
                        : isProcessing
                            ? const Color(0xFFE0F2FE)
                            : isRejected
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPending) ...[
                        const Icon(Icons.schedule_rounded, size: 9, color: Color(0xFFD97706)),
                        const SizedBox(width: 2.5),
                      ] else if (isProcessing) ...[
                        const Icon(Icons.near_me_rounded, size: 9, color: Color(0xFF0284C7)),
                        const SizedBox(width: 2.5),
                      ],
                      Text(
                        isPending
                            ? 'Pending'
                            : isProcessing
                                ? 'On The Way'
                                : isRejected
                                    ? 'Rejected'
                                    : 'Transferred',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? const Color(0xFFD97706)
                              : isProcessing
                                  ? const Color(0xFF0284C7)
                                  : isRejected
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isPositive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Earned',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ] else if (category == 'commission') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Fee',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
