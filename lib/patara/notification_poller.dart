import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend_api_service.dart';
import '../services/local_notification_service.dart';

/// Memeriksa pemberitahuan Orang Tua dan Delegasi dari server dan menampilkannya sebagai
/// notifikasi perangkat (permintaan akses, persetujuan, laporan baru, hasil validasi,
/// pencabutan). Selama aplikasi terbuka diperiksa tiap 45 detik; saat aplikasi tertutup,
/// BackgroundNotificationService memanggil check() kira-kira tiap 15 menit (Android).
class NotificationPoller {
  static const _seenKey = 'patara_seen_notification_ids';
  static const _interval = Duration(seconds: 45);

  Timer? _timer;
  bool _checking = false;
  String? _userId;

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => check());
    check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Mengembalikan jumlah pemberitahuan baru yang ditampilkan.
  Future<int> check() async {
    if (_checking) return 0;
    _checking = true;
    try {
      final items = await BackendApiService.getDelegationNotifications();
      final prefs = await SharedPreferences.getInstance();
      // Pemeriksaan latar belakang berjalan di isolat lain dan ikut menulis daftar "sudah dilihat";
      // baca ulang dari penyimpanan supaya pemberitahuan yang sama tidak dibunyikan dua kali.
      await prefs.reload();
      // Daftar "sudah dilihat" disimpan per akun, supaya berganti akun di perangkat yang sama
      // tidak membunyikan ulang riwayat lama akun tersebut.
      _userId ??= (await BackendApiService.getCurrentUser())?.id;
      if (_userId == null) return 0;
      final seenKey = '${_seenKey}_$_userId';
      final stored = prefs.getStringList(seenKey);
      final seen = {...?stored};
      final fresh = [
        for (final item in items)
          if (!seen.contains('${item['id']}')) item,
      ];
      await prefs.setStringList(seenKey, [
        for (final item in items.take(200)) '${item['id']}',
      ]);
      // Pada pemeriksaan pertama di perangkat ini, riwayat lama tidak dibunyikan ulang.
      if (stored == null || fresh.isEmpty) return 0;
      if (!await LocalNotificationService.ensurePermission()) return 0;
      for (final item in fresh.reversed) {
        await LocalNotificationService.showNotification(
          title: 'TARA',
          body: '${item['message']}',
          payload: 'delegation:${item['id']}',
        );
      }
      return fresh.length;
    } catch (_) {
      return 0;
    } finally {
      _checking = false;
    }
  }
}
