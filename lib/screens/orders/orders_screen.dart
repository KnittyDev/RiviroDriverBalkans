import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/ride_alert_service.dart';
import '../navigation/ride_navigation_screen.dart';
import 'widgets/orders_header.dart';
import 'widgets/active_ride_card.dart';
import 'widgets/order_item_card.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0; // 0: Active Rides, 1: History
  bool _isAlertActive = false;

  Timer? _countdownTicker;
  double _progressValue = 1.0; // 1.0 -> 0.0 over 12 seconds
  int _remainingSeconds = 12;

  StreamSubscription<RideAlertDebugInfo>? _debugSubscription;
  RideAlertDebugInfo? _latestDebugInfo;
  final List<String> _debugLogs = [];

  final List<Map<String, String>> _completedOrders = const [
    {
      'date': 'Today, 12:45 PM',
      'passenger': 'Marcus Vance',
      'rating': '5.0',
      'pickup': 'Center Siedlce, Poland',
      'dropoff': 'Galeria Siedlce, Poland',
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
    {
      'date': 'Yesterday, 08:30 PM',
      'passenger': 'Lucas Meyer',
      'rating': '5.0',
      'pickup': 'Downtown Metro Station',
      'dropoff': 'Riverside Residence, Block 4',
      'fare': '+15.20€',
      'distance': '3.8 km',
      'duration': '11 min',
      'tripId': '#TR-8890',
    },
    {
      'date': 'Yesterday, 05:10 PM',
      'passenger': 'Amara Okafor',
      'rating': '4.8',
      'pickup': 'Tech Hub Campus, Gate 2',
      'dropoff': 'City Center Shopping Mall',
      'fare': '+19.80€',
      'distance': '5.1 km',
      'duration': '14 min',
      'tripId': '#TR-8874',
    },
  ];

  @override
  void initState() {
    super.initState();
    _debugSubscription = RideAlertService().debugStream.listen((info) {
      if (mounted) {
        setState(() {
          _latestDebugInfo = info;
          _debugLogs.insert(0, info.logMessage);
        });
      }
    });
  }

  void _triggerRideAlertSimulation() {
    _countdownTicker?.cancel();

    setState(() {
      _isAlertActive = true;
      _debugLogs.clear();
      _latestDebugInfo = null;
      _progressValue = 1.0;
      _remainingSeconds = 12;
    });

    const totalMs = 12000;
    final startTime = DateTime.now();

    _countdownTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      final remainingMs = totalMs - elapsedMs;

      if (remainingMs <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _progressValue = 0.0;
            _remainingSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _progressValue = remainingMs / totalMs;
            _remainingSeconds = (remainingMs / 1000).ceil();
          });
        }
      }
    });

    RideAlertService().startRideAlert(
      onTimeout: () {
        _countdownTicker?.cancel();
        if (mounted) {
          setState(() {
            _isAlertActive = false;
            _progressValue = 1.0;
            _remainingSeconds = 12;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ride Request Timed Out (12s limit reached - 5 pulses).',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  void _stopRideSimulation(String action) {
    _countdownTicker?.cancel();
    RideAlertService().stopAlert();
    setState(() {
      _isAlertActive = false;
      _progressValue = 1.0;
      _remainingSeconds = 12;
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _debugSubscription?.cancel();
    RideAlertService().stopAlert();
    super.dispose();
  }

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
            top: 12,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with Tab Switcher
              OrdersHeader(
                selectedTab: _selectedTab,
                onTabChanged: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Ride Alert Audio Simulator Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bug_report_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ride Alert Realtime Debugger',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            _isAlertActive
                                ? 'Countdown: ${_remainingSeconds}s remaining (${(_progressValue * 100).toInt()}%)'
                                : '1.1s audio • 2.4s repeat • 12s timeout',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _isAlertActive
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontWeight: _isAlertActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isAlertActive
                          ? () => _stopRideSimulation('decline')
                          : _triggerRideAlertSimulation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAlertActive
                            ? Colors.redAccent
                            : AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isAlertActive ? 'Stop' : 'Simulate',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _isAlertActive
                              ? Colors.white
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Live Debug Monitor Terminal Box
              if (_debugLogs.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.textDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isAlertActive
                                      ? AppColors.primary
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'REALTIME DEBUG LOGS',
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Interval: 2400ms',
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _debugLogs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _debugLogs[index],
                                style: GoogleFonts.firaCode(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Tab Contents
              if (_selectedTab == 0) ...[
                // ACTIVE RIDES TAB (Active Ongoing Ride + Upcoming Request)

                // A. ONGOING ACTIVE RIDE (Driver accepted, in progress)
                Text(
                  'Ongoing Ride',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                ActiveRideCard(
                  cardType: RideCardType.ongoing,
                  passengerName: 'Marcus Vance',
                  passengerRating: '5.0',
                  fare: '24.50€',
                  distance: '1.4 km',
                  duration: '5 min',
                  pickupLocation: 'Center Siedlce, Poland',
                  dropoffLocation: 'Galeria Siedlce, Poland',
                  onCallPassenger: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Calling Marcus Vance...',
                              style: GoogleFonts.poppins(fontSize: 12.5),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.textDark,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onMessagePassenger: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Opening chat with Marcus Vance...',
                              style: GoogleFonts.poppins(fontSize: 12.5),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.textDark,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onCompleteRide: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Trip completed successfully!',
                          style: GoogleFonts.poppins(fontSize: 12.5),
                        ),
                        backgroundColor: AppColors.textDark,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onGoToLocation: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RideNavigationScreen(
                          passengerName: 'Marcus Vance',
                          pickupAddress: 'Center Siedlce, Poland',
                          dropoffAddress: 'Galeria Siedlce, Poland',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // B. UPCOMING INCOMING RIDE REQUEST
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Incoming Request',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (_isAlertActive)
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ALERTING (${_remainingSeconds}s)...',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ActiveRideCard(
                  cardType: RideCardType.upcoming,
                  passengerName: 'Sophia M.',
                  passengerRating: '4.9',
                  fare: '18.50€',
                  distance: '4.2 km',
                  duration: '12 min',
                  pickupLocation: 'Airport Terminal 2',
                  dropoffLocation: 'Grand Hyatt Hotel, Central St.',
                  isAlerting: _isAlertActive,
                  progressValue: _progressValue,
                  remainingSeconds: _remainingSeconds,
                  onAccept: () => _stopRideSimulation('accept'),
                  onDecline: () => _stopRideSimulation('decline'),
                ),
              ] else ...[
                // TRIP HISTORY TAB
                Text(
                  'Trip History',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                ..._completedOrders.map(
                      (order) => OrderItemCard(
                        date: order['date']!,
                        passengerName: order['passenger']!,
                        passengerRating: order['rating']!,
                        pickup: order['pickup']!,
                        dropoff: order['dropoff']!,
                        fare: order['fare']!,
                        distance: order['distance']!,
                        duration: order['duration']!,
                        tripId: order['tripId']!,
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
