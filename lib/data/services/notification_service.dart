import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart'; // For MethodChannel
import '../../core/app_strings.dart'; 

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static const platform = MethodChannel('com.example.expense_tracker/timezone');

  bool _isInitialized = false;

  Future<void> init(Function(NotificationResponse)? onResponse) async {
    if (_isInitialized) return;

    // Initialize Time Zones
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await platform.invokeMethod('getLocalTimezone');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print("Could not get local timezone: $e");
    }

    // Android Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Setup
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
      AppStrings.updatesChannelId,
      AppStrings.updatesChannelName,
      description: AppStrings.updatesChannelDesc,
      importance: Importance.high,
    );

    // Create Reminder Channel
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      AppStrings.reminderChannelId,
      AppStrings.reminderChannelName,
      description: AppStrings.reminderChannelDesc,
      importance: Importance.high,
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      await androidImplementation.createNotificationChannel(reminderChannel);
    }

    _isInitialized = true;
  }

  Future<bool?> requestPermissions() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission();
    }
    return null;
  }



  Future<void> showUpdateNotification(String version, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      AppStrings.updatesChannelId,
      AppStrings.updatesChannelName,
      channelDescription: AppStrings.updatesChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // ID
      '${AppStrings.updateTitle}$version',
      AppStrings.updateBody,
      platformChannelSpecifics,
      payload: AppStrings.payloadUpdateCheck,
    );
  }

  Future<void> scheduleDailyNotification(int hour, int minute) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        1, // Reminder ID
        AppStrings.dailyReminderTitle,
        AppStrings.dailyReminderBody,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                AppStrings.reminderChannelId,
                AppStrings.reminderChannelName,
                channelDescription: AppStrings.reminderChannelDesc,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
            )),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
