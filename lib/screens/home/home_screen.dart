import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/driver_stats_service.dart';
import '../../services/online_duration_service.dart';
import '../../services/supabase_location_tracker_service.dart';
import '../../services/hot_potato_dispatch_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settle_debt_modal.dart';
import '../orders/widgets/order_item_card.dart';
import 'widgets/home_header.dart';
import 'widgets/status_toggle_card.dart';
import 'widgets/radius_selector_card.dart';
import 'widgets/quick_stats_strip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  double _selectedRadiusKm = 10.0; // Default service radius in km
  List<Map<String, dynamic>> _recentTrips = [];
  bool _isLoadingTrips = true;
  RealtimeChannel? _homeRidesChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OnlineDurationService.init(
      isCurrentlyOnline: AuthService.currentDriverNotifier.value?.isOnline ?? false,
    );
    _loadHomeData();
    _subscribeToRidesRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_homeRidesChannel != null) {
      Supabase.instance.client.removeChannel(_homeRidesChannel!);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      OnlineDurationService.syncSession();
    }
  }

  void _subscribeToRidesRealtime() {
    _homeRidesChannel = Supabase.instance.client
        .channel('public:rides:home_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          callback: (payload) {
            _loadHomeData(isBackground: true);
          },
        )
        .subscribe();
  }

  Future<void> _loadHomeData({bool isBackground = false}) async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (!isBackground && mounted) {
      setState(() {
        _isLoadingTrips = true;
      });
    }

    try {
      DriverStatsService.fetchDriverLiveStats(driverId);

      var filterBuilder = Supabase.instance.client
          .from('rides')
          .select()
          .inFilter('status', ['completed', 'finished']);

      if (driverId != null && driverId.isNotEmpty) {
        filterBuilder = filterBuilder.or('driver_id.eq.$driverId,assigned_driver_id.eq.$driverId');
      }

      final response = await filterBuilder
          .order('created_at', ascending: false)
          .limit(5);
      final List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _recentTrips = fetched;
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error loading recent trips: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrips = false;
        });
      }
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final DateTime dt = DateTime.parse(timestamp.toString()).toLocal();
      final DateTime now = DateTime.now();
      final difference = now.difference(dt);

      final hourStr = dt.hour.toString().padLeft(2, '0');
      final minuteStr = dt.minute.toString().padLeft(2, '0');
      final timeStr = '$hourStr:$minuteStr';

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, $timeStr';
      } else if (difference.inDays == 1 || (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1)) {
        return 'Yesterday, $timeStr';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}, $timeStr';
      }
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadHomeData(),
          color: AppColors.textDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 14,
              bottom: safeBottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hello Driver Header
                const HomeHeader(),
                const SizedBox(height: 18),

                // 2. Online / Offline Status Toggle Card (Connected to Supabase)
                ValueListenableBuilder<DriverProfileModel?>(
                  valueListenable: AuthService.currentDriverNotifier,
                  builder: (context, driver, child) {
                    final isOnline = driver?.isOnline ?? true;
                    return StatusToggleCard(
                      isOnline: isOnline,
                      onToggle: (value) async {
                        final success = await AuthService.updateOnlineStatus(value);
                        if (!mounted) return;

                        if (value && !success) {
                          // Debt limit reached!
                          final currentBalance = DriverStatsService.statsNotifier.value.totalBalance;
                          _showDebtLimitBlockedDialog(currentBalance);
                          return;
                        }

                        if (value) {
                          SupabaseLocationTrackerService().startLocationTracking();
                        }
                        
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'You are now Online! Location tracking active.'
                                  : 'You are now Offline. Location tracking paused.',
                              style: GoogleFonts.poppins(fontSize: 12.5),
                            ),
                            backgroundColor: value ? AppColors.textDark : Colors.grey.shade800,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Pickup Service Radius Selector Card (1 km to 15 km)
                RadiusSelectorCard(
                  currentRadiusKm: _selectedRadiusKm,
                  onRadiusChanged: (newRadius) {
                    setState(() {
                      _selectedRadiusKm = newRadius;
                    });
                    HotPotatoDispatchService.updateServiceRadius(newRadius);
                  },
                ),
                const SizedBox(height: 18),

                // 4. Quick Stats Strip (Earnings, Trips, Online Time)
                Text(
                  'Today\'s Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<DriverStatsModel>(
                  valueListenable: DriverStatsService.statsNotifier,
                  builder: (context, stats, child) {
                    return ValueListenableBuilder<String>(
                      valueListenable: OnlineDurationService.onlineTimeStringNotifier,
                      builder: (context, onlineTimeStr, child) {
                        return QuickStatsStrip(
                          todayEarnings: stats.formatCurrency(stats.earningsToday),
                          todayTrips: '${stats.tripsToday} Trips',
                          onlineTime: onlineTimeStr,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 5. Recent Trips Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Trips',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (_recentTrips.isNotEmpty)
                      Text(
                        '${_recentTrips.length} completed',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoadingTrips)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.textDark,
                      ),
                    ),
                  )
                else if (_recentTrips.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 24,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No Recent Trips Yet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Completed rides will appear here automatically.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._recentTrips.map((order) {
                    final rideId = order['id']?.toString() ?? '';
                    final fareNum = (order['fare_amount'] as num?)?.toDouble() ?? 0.0;
                    final fareStr = CurrencyHelper.formatFare(
                      fareNum,
                      currencySymbol: order['currency_symbol']?.toString(),
                      currencyCode: order['currency_code']?.toString(),
                      includePlus: true,
                    );
                    final dateFormatted = _formatDateTime(order['created_at']);
                    final tripShortId = '#TR-${rideId.length >= 4 ? rideId.substring(0, 4).toUpperCase() : '0000'}';

                    return OrderItemCard(
                      rideId: rideId,
                      date: dateFormatted,
                      passengerName: order['passenger_name'] ?? 'Passenger',
                      passengerAvatarUrl: order['passenger_avatar_url'],
                      passengerRating: '5.0',
                      pickup: order['pickup_address'] ?? 'Pickup Location',
                      dropoff: order['destination_address'] ?? 'Destination Location',
                      fare: fareStr,
                      distance: '6.4 km',
                      duration: '18 min',
                      tripId: tripShortId,
                      paymentMethod: order['payment_method'] ?? 'Online',
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDebtLimitBlockedDialog(double currentBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom + 18;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 14,
            bottom: safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Alert Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Debt Limit Reached',
                style: GoogleFonts.poppins(
                  fontSize: 18.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final limitVal = DriverStatsService.debtLimitNotifier.value;
                  final stats = DriverStatsService.statsNotifier.value;
                  return Text(
                    'Your outstanding commission debt is ${stats.formatCurrency(currentBalance)} (Limit: ${stats.formatCurrency(-limitVal.abs())}). You cannot go online until this debt is settled.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 22),

              // Settle Debt Now Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    SettleDebtModal.show(context, currentDebt: currentBalance);
                  },
                  icon: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'Settle Debt Online',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
