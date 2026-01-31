import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to use other Firebase services in the background, 
  // initialize them here.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Service to handle all push notification logic
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  /// Initialize notification services
  Future<void> initialize() async {
    if (_initialized) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions');
    }

    // 2. Configure Local Notifications for foreground messages
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // 3. Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 4. Handle background messages (when app is opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 5. Build/Register device token with Supabase
    await _registerDeviceToken();

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _registerDeviceWithSupabase(newToken);
    });

    _initialized = true;
  }

  /// Get the current FCM token and register it with Supabase
  Future<void> _registerDeviceToken() async {
    try {
      debugPrint('NotificationService: Starting device token registration...');
      
      // For physical iOS devices, we need to wait for the APNs token to be available
      if (Platform.isIOS) {
        debugPrint('NotificationService: Checking APNs token for iOS...');
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('NotificationService: APNs token NOT AVAILABLE. Retrying in 3 seconds...');
          Future.delayed(const Duration(seconds: 3), _registerDeviceToken);
          return;
        }
        debugPrint('NotificationService: APNs token acquired: ${apnsToken.substring(0, 10)}...');
      }

      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('NotificationService: FCM Token acquired: ${token.substring(0, 10)}...');
        await _registerDeviceWithSupabase(token);
      } else {
        debugPrint('NotificationService: UNABLE to get FCM Token');
      }
    } catch (e) {
      debugPrint('NotificationService: Error getting FCM token: $e');
    }
  }

  /// Call the Supabase RPC to save the device token
  Future<void> _registerDeviceWithSupabase(String token) async {
    try {
      final client = Supabase.instance.client;
      debugPrint('NotificationService: Registering token with Supabase...');
      
      // Get a more descriptive device name
      String deviceName = 'Unknown Device';
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name; // e.g. "Yasser's iPhone"
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}'; // e.g. "Samsung SM-G991B"
      }
      
      await client.rpc('register_device_token', params: {
        'p_fcm_token': token,
        'p_device_name': deviceName,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
      
      debugPrint('NotificationService: Token registered successfully as "$deviceName"');
    } catch (e) {
      debugPrint('NotificationService: Supabase RPC registration failed: $e');
    }
  }

  /// Show a local notification when the app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('App opened via notification: ${message.data}');
    // Navigation logic can be added here
  }

  /// Subscribe/Unsubscribe to a team or tournament
  Future<bool> toggleSubscription({
    String? tournamentId,
    String? teamId,
  }) async {
    try {
      debugPrint('NotificationService: Toggling subscription...');
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('NotificationService: Cannot toggle, token is null');
        return false;
      }

      final client = Supabase.instance.client;
      final result = await client.rpc('toggle_subscription', params: {
        'p_fcm_token': token,
        'p_tournament_id': tournamentId,
        'p_team_id': teamId,
      });

      debugPrint('NotificationService: Toggle result: $result');
      return result as bool;
    } catch (e) {
      debugPrint('NotificationService: Error toggling subscription: $e');
      return false;
    }
  }
}
