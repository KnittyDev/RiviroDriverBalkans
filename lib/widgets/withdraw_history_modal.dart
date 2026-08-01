import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class WithdrawHistoryModal extends StatelessWidget {
  const WithdrawHistoryModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WithdrawHistoryModal(),
    );
  }

  static const List<Map<String, String>> historyData = [
    {
      'amount': '€1,245.00',
      'date': 'Today, 02:20 PM',
      'method': 'SEPA Express Instant',
      'status': 'Completed',
      'ref': '#TRX-9821-SEPA',
    },
    {
      'amount': '€450.00',
      'date': 'Yesterday, 09:15 AM',
      'method': 'SEPA Express Instant',
      'status': 'Completed',
      'ref': '#TRX-8910-SEPA',
    },
    {
      'amount': '€820.00',
      'date': '28 Jul 2026, 11:30 AM',
      'method': 'Standard Bank Transfer',
      'status': 'Completed',
      'ref': '#TRX-7812-STD',
    },
    {
      'amount': '€630.00',
      'date': '21 Jul 2026, 04:45 PM',
      'method': 'Standard Bank Transfer',
      'status': 'Completed',
      'ref': '#TRX-6901-STD',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
        bottom: safeBottomInset,
      ),
      child: Column(
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
                    child: const Icon(Icons.history_rounded, color: AppColors.textDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Withdrawal History',
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

          // History Items List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: historyData.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['amount']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item['method']} • ${item['date']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item['status']} ✓',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['ref']!,
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
