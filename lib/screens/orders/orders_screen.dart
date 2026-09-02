import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../navigation/ride_navigation_screen.dart';
import 'widgets/orders_header.dart';
import 'widgets/active_ride_card.dart';
import 'widgets/order_item_card.dart';
import '../../widgets/rider_contact_modal.dart';
import '../../widgets/rider_chat_modal.dart';
import '../../widgets/trip_review_modal.dart';
import '../../widgets/verify_ride_pin_modal.dart';
import '../../widgets/cancel_ride_modal.dart';
import '../../services/driver_stats_service.dart';
import '../../services/hot_potato_dispatch_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0; // 0: Active Rides, 1: History
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _activeRides = [];
  List<Map<String, dynamic>> _completedRides = [];

  RealtimeChannel? _ridesChannel;

  @override
  void initState() {
    super.initState();
    _fetchRidesFromSupabase();
    _subscribeToRidesRealtime();
  }

  @override
  void dispose() {
    if (_ridesChannel != null) {
      Supabase.instance.client.removeChannel(_ridesChannel!);
    }
    super.dispose();
  }

  /// Subscribes to live changes in public:rides table
  void _subscribeToRidesRealtime() {
    _ridesChannel = Supabase.instance.client
        .channel('public:rides:orders_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          callback: (payload) {
            _fetchRidesFromSupabase(isBackground: true);
          },
        )
        .subscribe();
  }

  /// Fetches real ride data from Supabase
  Future<void> _fetchRidesFromSupabase({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Advance expired hot potato offers and fail timed-out rides
      try {
        await Supabase.instance.client.rpc('expire_and_advance_hot_potato_rides');
      } catch (_) {}

      // 2. Fetch updated rides
      final response = await Supabase.instance.client
          .from('rides')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allRides = List<Map<String, dynamic>>.from(response);

      final active = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (final ride in allRides) {
        final status = (ride['status'] ?? '').toString().toLowerCase();
        // ONLY ACCEPTED / ONGOING RIDES in Active Orders tab!
        if (['accepted', 'on_the_way', 'arrived', 'in_progress'].contains(status)) {
          active.add(ride);
        } else if (['completed', 'finished', 'cancelled', 'failed'].contains(status)) {
          completed.add(ride);
        }
      }

      if (mounted) {
        setState(() {
          _activeRides = active;
          _completedRides = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [OrdersScreen] Error fetching rides: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load rides. Pull down to refresh.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $period';

      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[dt.month - 1];

      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return 'Today, $timeStr';
      } else if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
        return 'Yesterday, $timeStr';
      } else {
        return '${dt.day} $monthStr, $timeStr';
      }
    } catch (_) {
      return 'Recent';
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
          onRefresh: () => _fetchRidesFromSupabase(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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

                // 2. Loading / Error / Content State
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else if (_selectedTab == 0)
                  _buildActiveRidesSection()
                else
                  _buildHistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Active Rides Tab Content
  Widget _buildActiveRidesSection() {
    if (_activeRides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                size: 28,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Active Rides',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stay online to receive incoming Hot Potato ride offers!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Orders (${_activeRides.length})',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ..._activeRides.map((ride) {
          final rideId = ride['id']?.toString() ?? '';
          final fareNum = (ride['fare_amount'] as num?)?.toDouble() ?? 0.0;
          final fareStr = CurrencyHelper.formatFare(
            fareNum,
            currencySymbol: ride['currency_symbol']?.toString(),
            currencyCode: ride['currency_code']?.toString(),
          );
          final passengerName = ride['passenger_name'] ?? 'Passenger';
          final pickup = ride['pickup_address'] ?? 'Pickup Location';
          final dropoff = ride['destination_address'] ?? 'Destination Location';
          final payment = ride['payment_method'] ?? 'Online';
          final status = (ride['status'] ?? 'searching').toString();
          final isOngoing = status == 'accepted' || status == 'on_the_way' || status == 'in_progress' || status == 'arrived';
          final passengerAvatar = ride['passenger_avatar_url'] as String?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ActiveRideCard(
              cardType: isOngoing ? RideCardType.ongoing : RideCardType.upcoming,
              rideStatus: status,
              passengerName: passengerName,
              passengerAvatarUrl: passengerAvatar,
              passengerRating: '5.0',
              fare: fareStr,
              distance: '2.4 km',
              duration: '8 min',
              pickupLocation: pickup,
              dropoffLocation: dropoff,
              paymentMethod: payment,
              onCallPassenger: () {
                RiderContactModal.show(
                  context,
                  rideId: rideId,
                  passengerName: passengerName,
                  passengerRating: '5.0',
                  phoneNumber: ride['passenger_phone'] ?? '',
                  passengerAvatarUrl: passengerAvatar,
                );
              },
              onMessagePassenger: () {
                RiderChatModal.show(
                  context,
                  rideId: rideId,
                  passengerName: passengerName,
                  passengerRating: '5.0',
                  passengerPhone: ride['passenger_phone'] ?? '',
                  passengerAvatarUrl: passengerAvatar,
                );
              },
              onArrivedAtPickup: () async {
                await Supabase.instance.client
                    .from('rides')
                    .update({'status': 'arrived', 'updated_at': DateTime.now().toUtc().toIso8601String()})
                    .eq('id', rideId);
                _fetchRidesFromSupabase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Arrived at Pickup Location!',
                        style: GoogleFonts.poppins(fontSize: 12.5),
                      ),
                      backgroundColor: AppColors.textDark,
                    ),
                  );
                }
              },
              onStartRide: () async {
                final bool isVerified = await VerifyRidePinModal.show(
                  context,
                  rideId: rideId,
                  passengerName: passengerName,
                  passengerAvatarUrl: passengerAvatar,
                );

                if (isVerified && mounted) {
                  _fetchRidesFromSupabase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'PIN Verified! Ride Started.',
                        style: GoogleFonts.poppins(fontSize: 12.5),
                      ),
                      backgroundColor: const Color(0xFF22C55E),
                    ),
                  );
                }
              },
              onCompleteRide: () async {
                await Supabase.instance.client
                    .from('rides')
                    .update({'status': 'completed', 'updated_at': DateTime.now().toUtc().toIso8601String()})
                    .eq('id', rideId);
                
                await DriverStatsService.processRidePayout(rideId);
                _fetchRidesFromSupabase();
                DriverStatsService.fetchDriverLiveStats();
                if (mounted) {
                  TripReviewModal.show(
                    context,
                    rideId: rideId,
                    passengerName: passengerName,
                    passengerAvatarUrl: passengerAvatar,
                    fare: fareStr,
                    tripId: '#TR-${rideId.substring(0, 4).toUpperCase()}',
                  );
                }
              },
              onGoToLocation: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RideNavigationScreen(
                      rideId: rideId,
                      initialStatus: status,
                      passengerName: passengerName,
                      passengerPhone: ride['passenger_phone'] ?? '',
                      passengerAvatarUrl: passengerAvatar,
                      pickupAddress: pickup,
                      dropoffAddress: dropoff,
                      paymentMethod: payment,
                      fare: fareStr,
                    ),
                  ),
                ).then((_) => _fetchRidesFromSupabase());
              },
              onCancelRide: () {
                CancelRideModal.show(
                  context,
                  rideId: rideId,
                  passengerName: passengerName,
                  onCancelled: () => _fetchRidesFromSupabase(),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  /// History Tab Content
  Widget _buildHistorySection() {
    if (_completedRides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 28,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Trip History Yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed trips will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip History (${_completedRides.length})',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ..._completedRides.map((order) {
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
    );
  }
}

