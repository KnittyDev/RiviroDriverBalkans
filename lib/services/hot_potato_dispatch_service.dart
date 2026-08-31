import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'push_notification_service.dart';
import 'ride_alert_service.dart';
import '../screens/main_screen.dart';
import '../widgets/hot_potato_ride_offer_modal.dart';
import '../widgets/rider_chat_modal.dart';

class RideOfferModel {
  final String offerId;
  final String rideId;
  final String driverId;
  final int queueOrder;
  final double distanceKm;
  final DateTime expiresAt;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final double fareAmount;
  final String rideType;
  final String paymentMethod;
  final String passengerName;
  final String passengerPhone;
  final String? passengerAvatarUrl;

  RideOfferModel({
    required this.offerId,
    required this.rideId,
    required this.driverId,
    required this.queueOrder,
    required this.distanceKm,
    required this.expiresAt,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.fareAmount,
    this.rideType = 'Standard',
    this.paymentMethod = 'Cash',
    this.passengerName = 'Customer',
    this.passengerPhone = '',
    this.passengerAvatarUrl,
  });
}

class HotPotatoDispatchService {
  static final HotPotatoDispatchService _instance = HotPotatoDispatchService._internal();
  factory HotPotatoDispatchService() => _instance;
  HotPotatoDispatchService._internal();

  RealtimeChannel? _offersSubscriptionChannel;
  Timer? _pollingTimer;
  StreamSubscription? _notificationActionSub;
  StreamSubscription? _notificationTapSub;
  bool _isListening = false;
  String? _currentlyActiveOfferId;

  String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://dpxthqrofxsciaqbmnoq.supabase.co';
  String get _supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHRocXJvZnhzY2lhcWJtbm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MjQ3OTAsImV4cCI6MjEwMTMwMDc5MH0.cVjaM5oAxinicaal1BV9D0Qa1JbJolAE5doKjsYH3kA';

  /// Starts listening to Supabase Realtime for Hot Potato ride offers directed to this driver
  void startListening(BuildContext context) {
    if (_isListening) return;
    _isListening = true;

    final driverId = Supabase.instance.client.auth.currentUser?.id ??
        AuthService.currentDriverNotifier.value?.id;

    if (driverId == null || driverId.isEmpty) {
      debugPrint('ℹ️ [Hot Potato Dispatch] Cannot listen: Waiting for driver login.');
      _isListening = false;
      return;
    }

    debugPrint('🚀 [Hot Potato Dispatch] Realtime listener initialized for driver: $driverId');

    // 1. Subscribe to all changes in public:ride_offers
    _offersSubscriptionChannel = Supabase.instance.client
        .channel('public:ride_offers_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_offers',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty &&
                newRecord['driver_id']?.toString() == driverId &&
                newRecord['status'] == 'offered') {
              _handleIncomingOffer(context, newRecord);
            }
          },
        )
        .subscribe();

    // 2. Subscribe to Push Notification Action Clicks (Accept / Refuse buttons)
    _notificationActionSub?.cancel();
    _notificationActionSub = PushNotificationService.onNotificationAction.listen((data) async {
      final actionType = data['action_type']?.toString();
      final rideId = data['ride_id']?.toString() ?? '';
      final offerId = data['offer_id']?.toString() ?? '';
      final targetDriverId = data['driver_id']?.toString() ?? driverId;

      if (rideId.isEmpty) return;

      if (actionType == PushNotificationService.actionAccept) {
        debugPrint('🟢 [FCM Action Accept] Instant Optimistic Accept: $rideId');
        HotPotatoRideOfferModal.dismissCurrentModal();
        RideAlertService().stopAlert();
        PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
        MainScreen.switchToTab(1); // 0ms Instant Switch to Orders

        // Asynchronously process backend confirmation
        acceptRideOffer(rideId, offerId, targetDriverId);
      } else if (actionType == PushNotificationService.actionDecline) {
        debugPrint('🔴 [FCM Action Refuse] Instant Refuse: $rideId');
        HotPotatoRideOfferModal.dismissCurrentModal();
        RideAlertService().stopAlert();
        PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
        rejectRideOffer(rideId, offerId, targetDriverId);
      }
    });

    // 3. Subscribe to Notification Body Clicks (Open ride modal / chat modal in app)
    _notificationTapSub?.cancel();
    _notificationTapSub = PushNotificationService.onNotificationTap.listen((data) async {
      final type = data['type']?.toString() ?? 'ride_offer';
      final rideId = data['ride_id']?.toString() ?? '';

      // 3.1 Handle Chat Message Notification Click -> Open Live Chat Modal
      if (type == 'chat_message' || type == 'ride_message') {
        final senderName = data['sender_name']?.toString() ?? 'Passenger';
        final passengerPhone = data['passenger_phone']?.toString();
        final passengerAvatarUrl = data['passenger_avatar_url']?.toString();

        if (context.mounted && rideId.isNotEmpty) {
          debugPrint('💬 [FCM Chat Tap] Opening live chat modal for ride: $rideId');
          RiderChatModal.show(
            context,
            rideId: rideId,
            passengerName: senderName,
            passengerPhone: passengerPhone,
            passengerAvatarUrl: passengerAvatarUrl,
          );
        }
        return;
      }

      // 3.2 Handle Ride Offer Notification Click
      if (rideId.isNotEmpty) {
        // Check if this ride is already accepted
        try {
          final ride = await Supabase.instance.client
              .from('rides')
              .select('status, driver_id, assigned_driver_id')
              .eq('id', rideId)
              .maybeSingle();

          final status = (ride?['status'] ?? '').toString().toLowerCase();
          if (['accepted', 'arrived', 'in_progress'].contains(status)) {
            debugPrint('🚖 [FCM Tap] Ride $rideId already active ($status). Switching to Orders tab.');
            HotPotatoRideOfferModal.dismissCurrentModal();
            RideAlertService().stopAlert();
            MainScreen.switchToTab(1); // Orders tab
            return;
          }
        } catch (_) {}
      }

      if (context.mounted && data.isNotEmpty) {
        debugPrint('🚖 [FCM Tap] Showing ride offer modal from notification payload: $data');
        _handleIncomingOffer(context, data);
      }
    });

    // 4. Initial check for any pending active offer
    _checkForPendingOffers(context, driverId);

    // 5. Lightweight 3-second heartbeat polling to guarantee zero missed offers
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isListening && context.mounted) {
        _checkForPendingOffers(context, driverId);
      }
    });
  }

  /// Stops Realtime subscription and polling
  void stopListening() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _notificationActionSub?.cancel();
    _notificationActionSub = null;
    _notificationTapSub?.cancel();
    _notificationTapSub = null;
    if (_offersSubscriptionChannel != null) {
      Supabase.instance.client.removeChannel(_offersSubscriptionChannel!);
      _offersSubscriptionChannel = null;
    }
    _isListening = false;
  }

  /// Checks if an active offer is waiting for the driver
  Future<void> _checkForPendingOffers(BuildContext context, String driverId) async {
    try {
      // 0. STRICT CHECK: If driver currently has ANY active accepted/in_progress ride, DO NOT CHECK/SHOW OFFERS!
      final activeRide = await Supabase.instance.client
          .from('rides')
          .select('id, status')
          .or('driver_id.eq.$driverId,assigned_driver_id.eq.$driverId')
          .inFilter('status', ['accepted', 'arrived', 'in_progress'])
          .limit(1)
          .maybeSingle();

      if (activeRide != null) {
        HotPotatoRideOfferModal.dismissCurrentModal();
        RideAlertService().stopAlert();
        _currentlyActiveOfferId = null;
        return;
      }

      // 1. Auto-advance expired offers and expire timed-out rides
      try {
        await Supabase.instance.client.rpc('expire_and_advance_hot_potato_rides');
      } catch (_) {}

      // 2. Check in ride_offers for real active offer
      final response = await Supabase.instance.client
          .from('ride_offers')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'offered')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && context.mounted) {
        _handleIncomingOffer(context, response);
      }
    } catch (e) {
      debugPrint('Error checking pending ride offers: $e');
    }
  }

  /// Handles and displays the incoming 15-second Hot Potato ride offer
  Future<void> _handleIncomingOffer(BuildContext context, Map<String, dynamic> offerRecord) async {
    final offerId = offerRecord['id']?.toString() ?? '';
    final rideId = offerRecord['ride_id']?.toString() ?? '';
    final driverId = offerRecord['driver_id']?.toString() ?? '';
    final queueOrder = (offerRecord['queue_order'] as num?)?.toInt() ?? 1;
    final distanceKm = (offerRecord['distance_km'] as num?)?.toDouble() ?? 1.5;
    final expiresAt = DateTime.tryParse(offerRecord['expires_at'] ?? '') ??
        DateTime.now().add(const Duration(seconds: 15));

    // 0. ABSOLUTE CHECK: If driver has ANY active accepted ride, BLOCK modal completely!
    try {
      final activeRide = await Supabase.instance.client
          .from('rides')
          .select('id, status')
          .or('driver_id.eq.$driverId,assigned_driver_id.eq.$driverId')
          .inFilter('status', ['accepted', 'arrived', 'in_progress'])
          .limit(1)
          .maybeSingle();

      if (activeRide != null) {
        debugPrint('🛑 [Hot Potato] Driver already has active ride (${activeRide['id']}). Blocking offer modal!');
        HotPotatoRideOfferModal.dismissCurrentModal();
        RideAlertService().stopAlert();
        _currentlyActiveOfferId = null;
        return;
      }
    } catch (_) {}

    // Prevent duplicate modals for same offer
    if (_currentlyActiveOfferId == offerId) return;

    // Fetch full ride details and verify it's still available
    try {
      final rideData = await Supabase.instance.client
          .from('rides')
          .select()
          .eq('id', rideId)
          .maybeSingle();

      if (rideData == null || !context.mounted) return;

      final rideStatus = (rideData['status'] ?? '').toString().toLowerCase();
      if (['accepted', 'completed', 'cancelled', 'failed'].contains(rideStatus)) {
        debugPrint('ℹ️ [Hot Potato] Ride $rideId already finished ($rideStatus).');
        HotPotatoRideOfferModal.dismissCurrentModal();
        PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
        RideAlertService().stopAlert();

        if (rideStatus == 'accepted' &&
            (rideData['driver_id']?.toString() == driverId ||
             rideData['assigned_driver_id']?.toString() == driverId)) {
          MainScreen.switchToTab(1); // Orders Tab
        }
        return;
      }

      _currentlyActiveOfferId = offerId;

      final offerModel = RideOfferModel(
        offerId: offerId,
        rideId: rideId,
        driverId: driverId,
        queueOrder: queueOrder,
        distanceKm: distanceKm,
        expiresAt: expiresAt,
        pickupAddress: rideData['pickup_address'] ?? 'Pickup Location',
        pickupLat: (rideData['pickup_lat'] as num?)?.toDouble() ?? 42.444,
        pickupLng: (rideData['pickup_lng'] as num?)?.toDouble() ?? 19.278,
        destinationAddress: rideData['destination_address'] ?? 'Destination Location',
        destinationLat: (rideData['destination_lat'] as num?)?.toDouble() ?? 42.450,
        destinationLng: (rideData['destination_lng'] as num?)?.toDouble() ?? 19.285,
        fareAmount: (rideData['fare_amount'] as num?)?.toDouble() ?? 24.50,
        rideType: rideData['ride_type'] ?? 'Standard Ride',
        paymentMethod: rideData['payment_method'] ?? 'Cash',
        passengerName: rideData['passenger_name'] ?? 'Arif CAN',
        passengerPhone: rideData['passenger_phone'] ?? '',
        passengerAvatarUrl: rideData['passenger_avatar_url'],
      );

      // Play sound and trigger vibration alert
      RideAlertService().startRideAlert();

      // Show system notification with interactive Accept & Refuse action buttons
      PushNotificationService.showRideOfferNotification(
        id: rideId.hashCode & 0x7FFFFFFF,
        title: '🚖 New Ride Request (€${offerModel.fareAmount.toStringAsFixed(2)})',
        body: '${offerModel.pickupAddress} ➔ ${offerModel.destinationAddress}',
        payload: jsonEncode({
          'type': 'ride_offer',
          'ride_id': rideId,
          'offer_id': offerId,
          'driver_id': driverId,
          'fare_amount': offerModel.fareAmount,
          'pickup_address': offerModel.pickupAddress,
          'destination_address': offerModel.destinationAddress,
          'passenger_name': offerModel.passengerName,
        }),
      );

      // Display the interactive 15s Hot Potato Modal
      if (context.mounted) {
        HotPotatoRideOfferModal.show(
          context: context,
          offer: offerModel,
          onAccept: () => acceptRideOffer(rideId, offerId, driverId),
          onDecline: () => rejectRideOffer(rideId, offerId, driverId),
          onTimeout: () => expireRideOffer(rideId, offerId, driverId),
        );
      }
    } catch (e) {
      debugPrint('Error handling incoming offer: $e');
    }
  }

  /// Driver Accepts Ride Offer
  Future<bool> acceptRideOffer(String rideId, String offerId, String driverId) async {
    RideAlertService().stopAlert();
    HotPotatoRideOfferModal.dismissCurrentModal();
    PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
    MainScreen.switchToTab(1);
    _currentlyActiveOfferId = null;

    try {
      // 1. Direct RPC execution in Postgres for instant DB update with vehicle details
      try {
        await Supabase.instance.client.rpc('accept_ride_offer', params: {
          'p_ride_id': rideId,
          'p_offer_id': offerId.isNotEmpty ? offerId : null,
          'p_driver_id': driverId,
        });
      } catch (rpcErr) {
        debugPrint('ℹ️ [Hot Potato] accept_ride_offer RPC fallback: $rpcErr');
      }

      // 2. Edge Function invocation
      final endpoint = '$_supabaseUrl/functions/v1/dispatch-hot-potato';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'accept_offer',
          'ride_id': rideId,
          'offer_id': offerId,
          'driver_id': driverId,
        }),
      );

      debugPrint('✅ [Hot Potato] Offer Accepted: Status ${response.statusCode}, Body: ${response.body}');
      return true;
    } catch (e) {
      debugPrint('Error accepting ride offer: $e');
      return false;
    }
  }

  /// Driver Rejects Ride Offer (Passes to next closest driver immediately!)
  Future<void> rejectRideOffer(String rideId, String offerId, String driverId) async {
    RideAlertService().stopAlert();
    HotPotatoRideOfferModal.dismissCurrentModal();
    PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
    _currentlyActiveOfferId = null;

    try {
      final endpoint = '$_supabaseUrl/functions/v1/dispatch-hot-potato';
      await http.post(
        Uri.parse(endpoint),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'reject_offer',
          'ride_id': rideId,
          'offer_id': offerId,
          'driver_id': driverId,
        }),
      );
      debugPrint('🥔 [Hot Potato] Offer Rejected! Passed to next closest driver in queue.');
    } catch (e) {
      debugPrint('Error rejecting ride offer: $e');
    }
  }

  /// 15s Timer Expired (Auto-advances queue to next closest driver!)
  Future<void> expireRideOffer(String rideId, String offerId, String driverId) async {
    RideAlertService().stopAlert();
    HotPotatoRideOfferModal.dismissCurrentModal();
    PushNotificationService.cancelNotification(rideId.hashCode & 0x7FFFFFFF);
    _currentlyActiveOfferId = null;

    try {
      final endpoint = '$_supabaseUrl/functions/v1/dispatch-hot-potato';
      await http.post(
        Uri.parse(endpoint),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'expire_offer',
          'ride_id': rideId,
          'offer_id': offerId,
          'driver_id': driverId,
        }),
      );
      debugPrint('⏱️ [Hot Potato] 15s Timer Expired! Auto-passed to next closest driver.');
    } catch (e) {
      debugPrint('Error expiring ride offer: $e');
    }
  }

  /// Updates driver service range (km) in Supabase public.profiles
  static Future<bool> updateServiceRadius(double radiusKm) async {
    final driverId = Supabase.instance.client.auth.currentUser?.id ??
        AuthService.currentDriverNotifier.value?.id;

    if (driverId == null || driverId.isEmpty) return false;

    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('profiles').update({
        'service_radius_km': radiusKm,
        'updated_at': nowUtcIso,
      }).eq('id', driverId);

      debugPrint('🎯 [Service Radius] Updated service range to ${radiusKm.toStringAsFixed(1)} km for $driverId');
      return true;
    } catch (e) {
      debugPrint('Error updating service radius: $e');
      return false;
    }
  }
}
