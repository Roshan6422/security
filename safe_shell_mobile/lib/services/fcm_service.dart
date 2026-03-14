
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
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
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background Message Handler
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    } else {
      if (kDebugMode) print('User declined or has not accepted permission');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
      if (kDebugMode) print('Device token registered with Firebase');
    } catch (e) {
      if (kDebugMode) print('Failed to register device token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) print('Got a message whilst in the foreground!');
    if (kDebugMode) print('Message data: ${message.data}');

    if (message.notification != null) {
      _showLocalNotification(message);
    }

    // Handle Commands
    if (message.data.containsKey('command')) {
      _handleCommand(message.data);
    } else if (message.data['type'] == 'COMMAND') {
      _handleCommand(message.data);
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) print('Handling a background message: ${message.messageId}');
    if (message.data.containsKey('command')) {
      _handleCommand(message.data);
    } else if (message.data['type'] == 'COMMAND') {
      _handleCommand(message.data);
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'safeshell_channel',
      'SafeShell Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  static void _handleCommand(Map<String, dynamic> data) async {
    final command = data['command'] ?? data['type'];
    if (kDebugMode) print('Executing Command: $command');
    
    if (command == 'panic_lock') {
      try {
        final auth = FirebaseAuth.instance;
        await auth.signOut();
        // Since this is static, we can't easily navigate directly. 
        // But the next time the app is opened, it will see the user is logged out.
        // If we wanted immediate effect while app is open, we'd need a stream or global key.
        if (kDebugMode) print('Remote Panic Lock executed: User signed out.');
      } catch (e) {
        if (kDebugMode) print('Remote sign out failed: $e');
      }
    }
  }
}
