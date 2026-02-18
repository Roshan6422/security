import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundServiceConfig {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'safe_shell_service', // id
      'SafeShell Protection Service', // title
      description: 'This channel is used for important background protection notifications.', // description
      importance: Importance.low, // low importance to not annoy user
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'safe_shell_service',
        initialNotificationTitle: 'SafeShell Protection Active',
        initialNotificationContent: 'Your vault is being protected in the background.',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // bring to foreground
    Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          flutterLocalNotificationsPlugin.show(
            id: 888,
            title: 'SafeShell Protection Active',
            body: 'Your private files are secure.',
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'safe_shell_service',
                'SafeShell Protection Service',
                icon: 'ic_launcher',
                ongoing: true,
              ),
            ),
          );
        }
      }
    });
  }
}
