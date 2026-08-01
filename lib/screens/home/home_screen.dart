import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../orders/widgets/order_item_card.dart';
import 'widgets/home_header.dart';
import 'widgets/status_toggle_card.dart';
import 'widgets/quick_stats_strip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true; // Driver online status

  final List<Map<String, String>> _recentTrips = const [
    {
      'date': 'Today, 12:45 PM',
      'passenger': 'Marcus Vance',
      'rating': '5.0',
      'pickup': 'Central Park South, 4th Ave',
      'dropoff': 'Grand Hyatt Hotel, Central St.',
      'fare': '+24.50€',
      'distance': '6.4 km',
      'duration': '18 min',
      'tripId': '#TR-8921',
    },
    {
      'date': 'Today, 10:15 AM',
      'passenger': 'Elena Rostova',
      'rating': '4.9',
      'pickup': 'Airport Terminal 1, Gate B',
      'dropoff': 'West End Financial Sq.',
      'fare': '+38.00€',
      'distance': '14.2 km',
      'duration': '28 min',
      'tripId': '#TR-8919',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 14,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hello David Header
              const HomeHeader(
                name: 'David!',
              ),
              const SizedBox(height: 18),

              // 2. Online / Offline Status Toggle Card
              StatusToggleCard(
                isOnline: _isOnline,
                onToggle: (value) {
                  setState(() {
                    _isOnline = value;
                  });
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isOnline
                            ? 'You are now Online! Finding rides...'
                            : 'You are now Offline.',
                        style: GoogleFonts.poppins(fontSize: 12.5),
                      ),
                      backgroundColor: _isOnline ? AppColors.textDark : Colors.grey.shade800,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 3. Quick Stats Strip (Earnings, Trips, Online Time)
              Text(
                'Today\'s Summary',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              const QuickStatsStrip(
                todayEarnings: '124.50€',
                todayTrips: '8 Trips',
                onlineTime: '4h 12m',
              ),
              const SizedBox(height: 20),

              // 4. Recent Trips Section
              Text(
                'Recent Trips',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ..._recentTrips.map(
                (trip) => OrderItemCard(
                  date: trip['date']!,
                  passengerName: trip['passenger']!,
                  passengerRating: trip['rating']!,
                  pickup: trip['pickup']!,
                  dropoff: trip['dropoff']!,
                  fare: trip['fare']!,
                  distance: trip['distance']!,
                  duration: trip['duration']!,
                  tripId: trip['tripId']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
