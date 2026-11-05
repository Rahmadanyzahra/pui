import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'features/app_entry_screen.dart';
import 'features/maintenance_screen.dart';
import 'features/splash_screen.dart';
import 'services/backend_api_service.dart';
import 'services/background_notification_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  runApp(const MyApp());
  Future.microtask(() async {
    try {
      await LocalNotificationService.initialize();
    } catch (_) {}
    try {
      await BackgroundNotificationService.start();
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TARA',
      debugShowCheckedModeBanner: false,
      // Di browser laptop layarnya lebar; aplikasi ditampilkan selebar HP di tengah agar tidak melar.
      builder: (context, child) {
        // Mode pemeliharaan dari admin: layarnya menutupi aplikasi tanpa membuang layar yang sedang terbuka.
        final app = ValueListenableBuilder<MaintenanceInfo?>(
          valueListenable: BackendApiService.maintenance,
          builder: (context, info, _) => Stack(
            children: [
              child!,
              if (info != null) Positioned.fill(child: MaintenanceScreen(info: info)),
            ],
          ),
        );
        return !kIsWeb || MediaQuery.sizeOf(context).width <= 560
            ? app
            : ColoredBox(
                color: const Color(0xFFEDE7F6),
                child: Center(
                  child: SizedBox(
                    width: 480,
                    // Layar-layar yang bertanya "berapa lebar layar" juga harus mendapat lebar HP itu.
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: Size(480, MediaQuery.sizeOf(context).height)),
                      child: ClipRect(child: app),
                    ),
                  ),
                ),
              );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF06292),
          primary: const Color(0xFFF06292),
          secondary: const Color(0xFF9C27B0),
        ),
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFFFF6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF06292),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFCE4EC),
          elevation: 8,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF06292),
            foregroundColor: Colors.white,
          ),
        ),
        // Perpindahan antarlayar: layar baru memudar masuk sambil bergeser halus.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(nextScreen: AppEntryScreen()),
    );
  }
}
