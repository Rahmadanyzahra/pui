import 'package:flutter/material.dart';

import 'features/app_entry_screen.dart';
import 'features/splash_screen.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  Future.microtask(() async {
    try {
      await LocalNotificationService.initialize();
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patara AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF06292),
          primary: const Color(0xFFF06292),
          secondary: const Color(0xFF9C27B0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF2FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF06292),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF06292),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(nextScreen: AppEntryScreen()),
    );
  }
}
