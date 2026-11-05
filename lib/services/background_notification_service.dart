import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../patara/notification_poller.dart';
import 'backend_api_service.dart';

const _taskName = 'tara_cek_pemberitahuan';

/// Dijalankan Android di latar belakang (aplikasi tertutup pun), kira-kira tiap 15 menit:
/// mengambil pemberitahuan Orang Tua/Delegasi dari server dan menampilkannya di HP.
@pragma('vm:entry-point')
void taraBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await BackendApiService.initialize();
      // Tanpa sesi tersimpan (belum masuk atau sudah keluar) tidak ada yang diperiksa.
      if (!BackendApiService.hasSession) return true;
      await NotificationPoller().check();
    } catch (_) {
      // Gagal sekali (mis. server mati) tidak apa-apa; pemeriksaan berikutnya mencoba lagi.
    }
    return true;
  });
}

class BackgroundNotificationService {
  /// Mendaftarkan pemeriksaan berkala. Android menetapkan jarak minimal 15 menit dan bisa
  /// menundanya saat baterai hemat. iOS belum didukung: butuh pengaturan Xcode/APNs.
  static Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(taraBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
