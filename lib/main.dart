// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/firebase_options.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/expense_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'data/services/notification_service.dart';
import 'data/services/update_service.dart';
import 'core/global_events.dart';

// Top-level function for background work
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    if (task == 'update_check_task') {
       // Initialize deps if needed (Firebase not needed for update check usually, but path_provider is safe)
       // We rely on UpdateService.checkAndNotify which uses http
       await UpdateService.checkAndNotify();
    }
    return Future.value(true);
  });
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Background Updates are for Android/iOS only, not Web
  if (!kIsWeb) {
    try {
      // Initialize Notification Service
      final notificationService = NotificationService();
      await notificationService.init((NotificationResponse response) {
         // Handle tap
         if (response.payload == 'update_check') {
            GlobalEvents.trigger('open_update_check');
         }
      });
      
      // Schedule Daily Reminder (9 PM)
      await notificationService.scheduleDailyNotification(21, 0);

      // Initialize Workmanager
      await Workmanager().initialize(
          callbackDispatcher, 
          isInDebugMode: false 
      );
      
      // Register Periodic Task
      await Workmanager().registerPeriodicTask(
        "update_check_task",
        "update_check_task",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      print("Failed to initialize background services: $e");
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ExpenseProvider>(
          create: (_) => ExpenseProvider(),
          update: (_, auth, expenseProvider) {
            expenseProvider!.setUserId(auth.user?.uid);
            return expenseProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // Or handle state for this
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (auth.user == null) {
      return const LoginScreen();
    }
    
    return const HomeScreen();
  }
}
