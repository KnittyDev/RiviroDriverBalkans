import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'encryption_service.dart';
import 'ride_alert_service.dart';
import '../widgets/rider_chat_modal.dart';

/// Top-level background notification response handler
@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint('🔔 [FCM Background Notification Action] Clicked: ${response.actionId}, payload: ${response.payload}');
}

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('🔔 [FCM Background] Received message: ${message.messageId}, data: ${message.data}');

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleBackgroundNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
    );

    final data = message.data;
    final type = data['type']?.toString() ?? 'ride_offer';

    if (type == 'ride_offer') {
      final fare = data['fare_amount'] != null ? '€${data['fare_amount']}' : 'New Ride';
      final pickup = data['pickup_address']?.toString() ?? 'Pickup Location';
      final destination = data['destination_address']?.toString() ?? 'Destination';
      final rideId = data['ride_id']?.toString() ?? '${DateTime.now().millisecondsSinceEpoch}';

      final androidDetails = AndroidNotificationDetails(
        'ride_alerts_channel',
        'Ride Request Alerts',
        channelDescription:
            'High-priority sound and banner notifications for incoming driver ride requests.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Incoming Ride Request',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'action_accept',
            'Accept ✓',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'action_decline',
            'Refuse ✕',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      await localNotifications.show(
        rideId.hashCode & 0x7FFFFFFF,
        '🚖 New Ride Request ($fare)',
        '$pickup ➔ $destination',
        NotificationDetails(android: androidDetails),
        payload: jsonEncode(data),
      );
    } else if (type == 'chat_message' || type == 'ride_message') {
      final rideId = data['ride_id']?.toString() ?? '';
      final senderName = data['sender_name']?.toString() ?? 'Passenger';
      final encryptedPayload = data['encrypted_payload']?.toString() ?? '';
      final iv = data['iv']?.toString() ?? '';
      final messageId = data['message_id']?.toString() ?? '';

      String displayMessage = 'New message received';

      if (encryptedPayload.isNotEmpty && iv.isNotEmpty && rideId.isNotEmpty) {
        final decrypted = EncryptionService.decryptMap(
          rideId: rideId,
          encryptedBase64: encryptedPayload,
          ivBase64: iv,
        );
        if (decrypted != null) {
          final msg = decrypted['message']?.toString() ?? '';
          final imageUrl = decrypted['image_url']?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            displayMessage = '📷 Photo';
          } else if (msg.isNotEmpty) {
            displayMessage = msg;
          }
        }
      }

      final notificationId = (messageId.isNotEmpty
              ? messageId.hashCode
              : DateTime.now().millisecondsSinceEpoch) &
          0x7FFFFFFF;

      final chatAndroidDetails = AndroidNotificationDetails(
        'chat_messages_channel',
        'Passenger Messages',
        channelDescription: 'Real-time encrypted in-ride chat messages from passengers.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        groupKey: 'chat_group_$rideId',
        setAsGroupSummary: false,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          displayMessage,
          contentTitle: '💬 $senderName',
          summaryText: 'Passenger Message',
        ),
      );

      await localNotifications.show(
        notificationId,
        '💬 $senderName',
        displayMessage,
        NotificationDetails(android: chatAndroidDetails),
        payload: jsonEncode(data),
      );
    }
  } catch (e) {
    debugPrint('⚠️ [FCM Background] Error handling background message: $e');
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ride_alerts_channel';
  static const String _channelName = 'Ride Request Alerts';
  static const String _channelDescription =
      'High-priority sound and banner notifications for incoming driver ride requests.';

  static const String _chatChannelId = 'chat_messages_channel';
  static const String _chatChannelName = 'Passenger Messages';
  static const String _chatChannelDescription =
      'Real-time encrypted in-ride chat messages from passengers.';

  static const String actionAccept = 'action_accept';
  static const String actionDecline = 'action_decline';

  // Streams for handling notification actions and taps across the app
  static final StreamController<Map<String, dynamic>> _notificationActionController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onNotificationAction =>
      _notificationActionController.stream;

  static final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  static bool _isInitialized = false;

  /// Initializes FCM and Local Notifications
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request iOS & Android 13+ Notification Permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 [FCM] Notification authorization status: ${settings.authorizationStatus}');

      // 3. Initialize Local Notifications Plugin
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _handleNotificationResponse,
      );

      // 4. Create High-Priority Android Notification Channels (Ride Alerts & Chat Messages)
      final androidRideChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
      );

      final androidChatChannel = const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(androidRideChannel);
      await androidPlugin?.createNotificationChannel(androidChatChannel);

      // 5. Enable foreground heads-up display on iOS & Android
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Listen to foreground incoming FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Received: ${message.notification?.title} | Data: ${message.data}');
        _handleForegroundMessage(message);
      });

      // 7. Listen to notification open when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🚀 [FCM Open] App opened via notification: ${message.data}');
        _notificationTapController.add(message.data);
      });

      // 8. Check if app was opened from terminated state by a notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 [FCM Initial] App launched from notification: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 1200), () {
          _notificationTapController.add(initialMessage.data);
        });
      }

      // 9. Fetch & save initial FCM token
      await syncTokenWithSupabase();

      // 10. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [FCM Token Refresh] New token received: $newToken');
        await _saveTokenToSupabase(newToken);
      });

      _isInitialized = true;
      debugPrint('✅ [PushNotificationService] Initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ [PushNotificationService] Initialization error: $e\n$stack');
    }
  }

  /// Fetches the latest device FCM token and saves to Supabase profiles
  static Future<String?> syncTokenWithSupabase() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('🔑 [FCM Token] Current Device Token: $token');
        await _saveTokenToSupabase(token);
        return token;
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Token] Error getting token: $e');
    }
    return null;
  }

  /// Persists token to Supabase profiles for active driver
  static Future<void> _saveTokenToSupabase(String token) async {
    final driverId = AuthService.currentDriverNotifier.value?.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (driverId == null || driverId.isEmpty) {
      debugPrint('ℹ️ [FCM Token] Driver ID not yet active. Skipping profile token update.');
      return;
    }

    try {
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);

      debugPrint('✅ [FCM Token] Saved fcm_token to Supabase for driver $driverId');
    } catch (e) {
      debugPrint('⚠️ [FCM Token] Failed updating fcm_token in Supabase: $e');
    }
  }

  /// Handles incoming FCM message in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? 'ride_offer';

    if (type == 'ride_offer') {
      final fare = data['fare_amount'] != null ? '€${data['fare_amount']}' : 'New Ride';
      final pickup = data['pickup_address']?.toString() ?? 'Pickup Location';
      final destination = data['destination_address']?.toString() ?? 'Destination';

      // Start sound & haptic alert
      RideAlertService().startRideAlert();

      // Show high-priority heads-up notification with Accept & Refuse action buttons
      await showRideOfferNotification(
        id: (data['ride_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF,
        title: '🚖 New Ride Request ($fare)',
        body: '$pickup ➔ $destination',
        payload: jsonEncode(data),
      );
    } else if (type == 'chat_message' || type == 'ride_message') {
      final rideId = data['ride_id']?.toString() ?? '';
      final senderName = data['sender_name']?.toString() ?? 'Passenger';
      final encryptedPayload = data['encrypted_payload']?.toString() ?? '';
      final iv = data['iv']?.toString() ?? '';

      // Don't pop up notification if driver is currently inside the chat screen for this ride
      if (RiderChatModal.activeChatRideId == rideId) {
        debugPrint('ℹ️ [FCM Foreground] Driver already in chat for ride $rideId. Suppressing popup notification.');
        return;
      }

      String displayMessage = 'New message received';

      if (encryptedPayload.isNotEmpty && iv.isNotEmpty && rideId.isNotEmpty) {
        final decrypted = EncryptionService.decryptMap(
          rideId: rideId,
          encryptedBase64: encryptedPayload,
          ivBase64: iv,
        );
        if (decrypted != null) {
          final msg = decrypted['message']?.toString() ?? '';
          final imageUrl = decrypted['image_url']?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            displayMessage = '📷 Photo';
          } else if (msg.isNotEmpty) {
            displayMessage = msg;
          }
        }
      }

      final messageId = data['message_id']?.toString() ?? '';
      final notificationId = (messageId.isNotEmpty
              ? messageId.hashCode
              : DateTime.now().millisecondsSinceEpoch) &
          0x7FFFFFFF;

      await showChatMessageNotification(
        id: notificationId,
        rideId: rideId,
        title: '💬 $senderName',
        body: displayMessage,
        payload: jsonEncode(data),
      );
    } else {
      // Generic notification
      final title = message.notification?.title ?? 'Rivilo Driver';
      final body = message.notification?.body ?? '';
      await showGenericNotification(
        title: title,
        body: body,
        payload: jsonEncode(data),
      );
    }
  }

  /// Shows in-ride chat message notification
  static Future<void> showChatMessageNotification({
    required int id,
    required String rideId,
    required String title,
    required String body,
    required String payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      _chatChannelName,
      channelDescription: _chatChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      groupKey: 'chat_group_$rideId',
      setAsGroupSummary: false,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Passenger Message',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Shows high-priority ride offer notification with Accept and Refuse action buttons
  static Future<void> showRideOfferNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Incoming Ride Request',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionAccept,
          'Accept ✓',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionDecline,
          'Refuse ✕',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Shows standard generic notification
  static Future<void> showGenericNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Callback when a user taps a notification or clicks an action button
  @pragma('vm:entry-point')
  static void _handleNotificationResponse(NotificationResponse response) {
    final payloadStr = response.payload;
    Map<String, dynamic> data = {};

    if (payloadStr != null && payloadStr.isNotEmpty) {
      try {
        data = jsonDecode(payloadStr);
      } catch (_) {}
    }

    final actionId = response.actionId;
    debugPrint('🔔 [Notification Action Clicked] Action: $actionId | Payload: $data');

    if (actionId == actionAccept || actionId == actionDecline) {
      data['action_type'] = actionId;
      _notificationActionController.add(data);
    } else {
      // Body of notification was clicked -> Open ride offer modal
      _notificationTapController.add(data);
    }
  }

  /// Cancels specific notification by ID
  static Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (_) {}
  }

  /// Cancels all active notifications
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
