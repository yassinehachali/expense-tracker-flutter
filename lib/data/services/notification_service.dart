import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init(Function(NotificationResponse)? onResponse) async {
    if (_isInitialized) return;

    // Android Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure this icon exists

    // iOS Setup (Minimal for now)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onResponse,
    );
    
    // Create Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'updates_channel', // id
      'App Updates', // title
      description: 'Notifications for new app updates',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  Future<void> showUpdateNotification(String version, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'updates_channel',
      'App Updates',
      channelDescription: 'Notifications for new app updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // ID
      'Update Available: $version',
      'A new version is available. Tap to update.',
      platformChannelSpecifics,
      payload: 'update_check', // Payload to handle navigation
    );
  }
}
