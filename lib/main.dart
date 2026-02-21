// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/firebase_options.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/expense_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/add_expense_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'core/app_strings.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

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



// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Language Settings (Load from Prefs)
  await AppStrings.init();
  
  // Enable Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Background Updates are for Android/iOS only, not Web
  if (!kIsWeb) {
    try {
      // Initialize Workmanager for background updates (runs in checkAndNotify)
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
      child: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return ValueListenableBuilder<String>(
            valueListenable: AppStrings.languageNotifier,
            builder: (context, lang, child) {
              return MaterialApp(
                navigatorKey: navigatorKey, // Assign Global Key
                title: AppStrings.appTitle,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.system, 
                locale: Locale(lang), // Use global persisted language
                supportedLocales: const [
                  Locale('en', ''),
                  Locale('fr', ''),
                  Locale('ar', ''),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const AuthWrapper(),
              );
            }
          );
        }
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWidgetLaunch();
    _setupWidgetListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetLaunch();
    }
  }

  Future<void> _checkWidgetLaunch() async {
    // Only check on Android/iOS
    if (kIsWeb) return;

    try {
      // 1. Check Native Flag via SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force reload
      
      bool launchIncome = prefs.getBool('widget_launch_add_income') ?? false;
      bool launchExpense = prefs.getBool('widget_launch_add_expense') ?? false;

      // Small retry loop
      if (!launchIncome && !launchExpense) {
         for (int i=0; i<3; i++) {
            await Future.delayed(const Duration(milliseconds: 200));
            await prefs.reload();
            launchIncome = prefs.getBool('widget_launch_add_income') ?? false;
            launchExpense = prefs.getBool('widget_launch_add_expense') ?? false;
            if (launchIncome || launchExpense) break;
         }
      }

      if (launchIncome) {
        await prefs.remove('widget_launch_add_income');
        _navigateToadd(type: 'income');
        return; 
      }
      
      if (launchExpense) {
        await prefs.remove('widget_launch_add_expense');
        _navigateToadd(type: 'expense');
        return;
      }

      // Backward compatibility (Small Widget - maps to Expense)
      final shouldLaunchLegacy = prefs.getBool('widget_launch_add') ?? false;
      if (shouldLaunchLegacy) {
         await prefs.remove('widget_launch_add');
         _navigateToadd(type: 'expense');
         return;
      }

      // 2. Fallback to HomeWidget Plugin (for backward compatibility or cold starts)
      final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (widgetUri != null && widgetUri.toString().contains('addTransaction')) {
         _navigateToadd(type: 'expense');
      }

    } catch (e) {
      // ignore
    }
  }

  void _navigateToadd({String type = 'expense'}) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300)); // Small delay for Resume state stability
        if (navigatorKey.currentState != null) {
           navigatorKey.currentState!.push(
             MaterialPageRoute(builder: (_) => AddExpenseScreen(initialType: type)),
           );
        }
      });
  }

  void _setupWidgetListener() {
    if (kIsWeb) return;
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null && uri.toString().contains('addTransaction')) {
         _navigateToadd(type: 'expense');
      }
    });
  }





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
