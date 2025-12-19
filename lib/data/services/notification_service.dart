import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
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

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = fln.FlutterLocalNotificationsPlugin();
  
  static const platform = MethodChannel('com.example.expense_tracker/timezone');

  bool _isInitialized = false;

  Future<void> init(Function(fln.NotificationResponse)? onResponse) async {
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
    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Setup
    const fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings();

    final fln.InitializationSettings initializationSettings = fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onResponse,
    );
    
    // Create Channel
    fln.AndroidNotificationChannel channel = fln.AndroidNotificationChannel(
      AppStrings.updatesChannelId,
      AppStrings.updatesChannelName,
      description: AppStrings.updatesChannelDesc,
      importance: fln.Importance.high,
    );

    // Create Reminder Channel
    fln.AndroidNotificationChannel reminderChannel = fln.AndroidNotificationChannel(
      AppStrings.reminderChannelId,
      AppStrings.reminderChannelName,
      description: AppStrings.reminderChannelDesc,
      importance: fln.Importance.high,
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      await androidImplementation.createNotificationChannel(reminderChannel);
    }

    _isInitialized = true;
  }

  Future<bool?> requestPermissions() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission();
    }
    return null;
  }



  Future<void> showUpdateNotification(String version, String body) async {
    fln.AndroidNotificationDetails androidPlatformChannelSpecifics =
        fln.AndroidNotificationDetails(
      AppStrings.updatesChannelId,
      AppStrings.updatesChannelName,
      channelDescription: AppStrings.updatesChannelDesc,
      importance: fln.Importance.high,
      priority: fln.Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    fln.NotificationDetails platformChannelSpecifics =
        fln.NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // ID
      '${AppStrings.updateTitle}$version',
      AppStrings.updateBody,
      platformChannelSpecifics,
      payload: AppStrings.payloadUpdateCheck,
    );
  }

  Future<void> scheduleDailyNotification(int hour, int minute) async {
    // zonedSchedule is not supported on Web and causes compilation errors due to missing symbols.
    // Temporarily disabled for Web compatibility.
    print("Daily reminder scheduling is not supported on this platform.");
    await flutterLocalNotificationsPlugin.zonedSchedule(
        1, // Reminder ID
        AppStrings.dailyReminderTitle,
        AppStrings.dailyReminderBody,
        _nextInstanceOfTime(hour, minute),
        fln.NotificationDetails(
            android: fln.AndroidNotificationDetails(
                AppStrings.reminderChannelId,
                AppStrings.reminderChannelName,
                channelDescription: AppStrings.reminderChannelDesc,
                importance: fln.Importance.high,
                priority: fln.Priority.high,
                icon: '@mipmap/ic_launcher',
            )),
        androidScheduleMode: fln.AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            fln.UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: fln.DateTimeComponents.time);
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
