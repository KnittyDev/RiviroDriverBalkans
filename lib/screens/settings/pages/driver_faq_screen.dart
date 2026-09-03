import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class DriverFaqScreen extends StatefulWidget {
  const DriverFaqScreen({super.key});

  @override
  State<DriverFaqScreen> createState() => _DriverFaqScreenState();
}

class _DriverFaqScreenState extends State<DriverFaqScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Rides & Offers',
    'Navigation',
    'PIN & Safety',
    'Wallet & Debt',
    'Payouts',
  ];

  final List<Map<String, dynamic>> _faqItems = [
    // Rides & Offers
    {
      'category': 'Rides & Offers',
      'icon': Icons.bolt_rounded,
      'question': 'How do I receive and accept ride offers?',
      'answer':
          'When you are Online, incoming ride offers will appear on your screen with a loud chime, vibration, and a 12-second countdown timer.\n\n'
          'To accept the ride, simply tap the "Accept Ride" button before the timer expires. You will immediately receive the passenger details, pickup location, and fare.',
      'tag': 'Hot Potato Dispatch',
    },
    {
      'category': 'Rides & Offers',
      'icon': Icons.timer_outlined,
      'question': 'What happens if I miss or decline an offer?',
      'answer':
          'Rivilo uses a "Hot Potato" fair dispatch algorithm. If you decline or let the 12-second timer expire, the ride automatically advances to the next closest available driver without penalizing your account or locking your screen.',
      'tag': 'Dispatch Rules',
    },
    {
      'category': 'Rides & Offers',
      'icon': Icons.power_settings_new_rounded,
      'question': 'How do I make sure I receive offers in the background?',
      'answer':
          'Ensure that your Location permission is set to "Allow all the time" in your device settings. Also ensure that Battery Optimization / App Sleep is disabled for Rivilo Driver so high-priority push notifications can instantly wake your screen even if the app is killed.',
      'tag': 'Device Settings',
    },

    // Navigation
    {
      'category': 'Navigation',
      'icon': Icons.navigation_rounded,
      'question': 'How does Turn-by-Turn navigation work?',
      'answer':
          'On your Active Orders card, tap "Navigate to Pickup" or "Navigate to Dropoff". The app will directly launch your phone\'s external navigation app (Google Maps on Android, Apple Maps or Google Maps on iOS) in driving turn-by-turn mode.\n\n'
          'You never have to manually copy or type addresses into external GPS apps.',
      'tag': 'Google & Apple Maps',
    },
    {
      'category': 'Navigation',
      'icon': Icons.sync_alt_rounded,
      'question': 'Does the navigation target update automatically?',
      'answer':
          'Yes! When you are heading towards the passenger, the navigation button targets their Pickup address. Once the passenger is in the vehicle and you start the ride, the button automatically switches to target their final Dropoff destination.',
      'tag': 'Dynamic Target',
    },

    // PIN & Safety
    {
      'category': 'PIN & Safety',
      'icon': Icons.pin_rounded,
      'question': 'What is the 6-digit Ride PIN and how do I use it?',
      'answer':
          'Every passenger receives a unique 6-digit PIN when ordering a ride. When you meet the passenger at pickup:\n\n'
          '1. Ask the passenger for their 6-digit PIN.\n'
          '2. Tap "Verify PIN & Start" on your Active Ride card.\n'
          '3. Enter the 6 digits to confirm identity and safely start the trip timer and meter.',
      'tag': 'Safety First',
    },
    {
      'category': 'PIN & Safety',
      'icon': Icons.phone_in_talk_rounded,
      'question': 'How can I call or message the passenger?',
      'answer':
          'On your Active Orders card, use the Call button to initiate a direct telephone call, or use the Message button to open the real-time in-app chat.',
      'tag': 'Communication',
    },
    {
      'category': 'PIN & Safety',
      'icon': Icons.cancel_outlined,
      'question': 'What if the passenger does not show up?',
      'answer':
          'Wait at the pickup point for at least 5 minutes and attempt to contact the passenger via call or message. If there is no response, you can tap the "Cancel" button on the active card and select "Passenger No-Show".',
      'tag': 'Cancellation',
    },

    // Wallet & Debt
    {
      'category': 'Wallet & Debt',
      'icon': Icons.account_balance_wallet_rounded,
      'question': 'Why is my balance negative? Am I blocked?',
      'answer':
          'You are NOT blocked! When passengers pay with Cash, you keep 100% of the cash fare in your physical pocket.\n\n'
          'The platform\'s small commission is recorded against your Driver Wallet balance as a negative amount. You can freely continue accepting rides until you reach your maximum debt limit (e.g. -30€ or -300 MKD).',
      'tag': 'Cash Rides',
    },
    {
      'category': 'Wallet & Debt',
      'icon': Icons.credit_card_rounded,
      'question': 'How do I balance or clear my commission debt?',
      'answer':
          'You can clear your balance in two easy ways:\n\n'
          '1. Automatic: Every completed online/card-paid ride will automatically deduct from your debt and bring your balance back to positive.\n'
          '2. Online Pay: Tap your Balance Card in the Profile tab and choose "Online Pay" to pay via credit/debit card instantly with Stripe.',
      'tag': 'Debt Settlement',
    },

    // Payouts
    {
      'category': 'Payouts',
      'icon': Icons.payments_rounded,
      'question': 'When and how do I receive my earnings & tips?',
      'answer':
          'All card-paid trip fares and passenger tips are credited to your Driver Wallet immediately upon trip completion.\n\n'
          'In the Profile tab, tap "Cash Out" to withdraw funds to your registered bank account (IBAN). Withdrawals arrive within 5-15 minutes via SEPA Instant Transfer or 1-2 business days via Standard Bank Transfer.',
      'tag': 'Bank Transfer',
    },
    {
      'category': 'Payouts',
      'icon': Icons.currency_exchange_rounded,
      'question': 'What currency does my wallet use?',
      'answer':
          'Your wallet automatically uses your registered country\'s official currency (Macedonian Denar MKD for North Macedonia, Euro € for Montenegro, Lek for Albania, RSD for Serbia).',
      'tag': 'Local Currencies',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFaqItems {
    return _faqItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return matchesCategory;

      final question = (item['question'] as String).toLowerCase();
      final answer = (item['answer'] as String).toLowerCase();
      final tag = (item['tag'] as String).toLowerCase();

      final matchesQuery = question.contains(query) || answer.contains(query) || tag.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
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
          'Driver FAQ & Guide',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Search help questions, wallet, navigation...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category Pills Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.textDark : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // FAQ List / Results
              if (_filteredFaqItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        'No matching answers found',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try searching for "wallet", "navigation", "PIN", or clear your filter.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredFaqItems.map((item) => _buildFaqTile(item)),

              const SizedBox(height: 20),

              // 24/7 Driver Support Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.textDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Further Assistance?',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Our 24/7 Driver Support team is available to assist you with any questions.',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryActiveBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: AppColors.textDark,
              size: 18,
            ),
          ),
          title: Text(
            item['question'] as String,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    item['tag'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          iconColor: AppColors.textDark,
          collapsedIconColor: AppColors.textMuted,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                item['answer'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
