
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final ApiService _apiService = ApiService();

  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted permission');
      
      // Initialize Local Notifications
      final AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
            // Handle notification tap
        },
      );

      // Get Token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        if (kDebugMode) print('FCM Token: $token');
        await _registerToken(token);
      }

      // Listen for Token Refresh
      _firebaseMessaging.onTokenRefresh.listen(_registerToken);

      // Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) print('Got a message whilst in the foreground!');
        if (kDebugMode) print('Message data: ${message.data}');

        if (message.notification != null) {
          _showNotification(message);
        }

        // Handle Commands
        if (message.data.containsKey('command')) {
          _handleCommand(message.data);
        } else if (message.data['type'] == 'COMMAND') {
          _handleCommand(message.data);
        }
      });

      // Background Message Handler (needs to be static/global, defined in main.dart usually but okay here if referenced)
    } else {
      if (kDebugMode) print('User declined or has not accepted permission');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      // Create a specialized instance or use existing if state management allows
      // For simplicity, we create a temporary instance or use static
      // Assuming ApiService handles auth tokens correctly from storage
      await _apiService.post('/device/register', {'token': token});
      if (kDebugMode) print('Device token registered with backend');
    } catch (e) {
      if (kDebugMode) print('Failed to register device token: $e');
    }
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'safeshell_channel',
      'SafeShell Notifications',
      channelDescription: 'SafeShell Notification Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  static void _handleCommand(Map<String, dynamic> data) async {
    String command = data['command'] ?? '';
    if (kDebugMode) print('Executing Command: $command');

    switch (command.toUpperCase()) {
      case 'LOCK_DEVICE':
      case 'LOCK':
        // Try to trigger the native app lock to overlay the screen
        try {
          const platform = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
          await platform.invokeMethod('showAppLock', {'packageName': 'com.safeshell.safe_shell_mobile'});
          if (kDebugMode) print('Triggered native AppLock screen');
        } catch (e) {
          if (kDebugMode) print('Failed to trigger native lock: $e');
        }
        break;
      case 'SOUND_ALARM':
      case 'ALARM':
        // TODO: Play sound natively or via audioplayers package
        if (kDebugMode) print('Would play loud alarm now!');
        break;
      case 'GET_LOCATION':
      case 'LOCATION':
        // TODO: Get location and send back
        if (kDebugMode) print('Would fetch and upload location now!');
        break;
      case 'WIPE_DATA':
        if (kDebugMode) print('Would wipe local data now!');
        break;
    }
  }
}
