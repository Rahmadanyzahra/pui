import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';

/// Layar penuh selama admin menyalakan mode pemeliharaan. Dipasang di atas semua layar (lihat main.dart),
/// sehingga posisi pengguna di aplikasi tidak hilang; statusnya diperiksa ulang setiap 30 detik dan layar
/// ini hilang sendiri begitu pemeliharaan selesai.
class MaintenanceScreen extends StatefulWidget {
  final MaintenanceInfo info;

  const MaintenanceScreen({super.key, required this.info});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() { _checking = true; });
    await BackendApiService.checkMaintenance();
    if (mounted) setState(() { _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.info.until;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: pataraGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(color: Color(0xFFFCE4EC), shape: BoxShape.circle),
                      child: const Icon(Icons.construction_rounded, size: 40, color: pataraPink),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'TARA sedang dalam pemeliharaan',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(widget.info.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.5)),
                    if (until != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          'Perkiraan selesai: ${DateFormat("EEEE, d MMMM y 'pukul' HH.mm", 'id_ID').format(until)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pataraPurple),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _checking ? null : _check,
                        icon: _checking
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded),
                        label: Text(_checking ? 'Memeriksa...' : 'Coba lagi'),
                        style: FilledButton.styleFrom(backgroundColor: pataraPink),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Catatan Anda tetap aman. Halaman ini memeriksa ulang otomatis setiap 30 detik.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
