import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Khusus Bayi (0-<1 tahun): catatan perawatan hari ini (menyusu, popok, tidur, tengkurap),
/// tombol catat cepat, anjuran rujukannya, dan imunisasi yang jadwal usianya sudah tiba.
class BabyCareCard extends StatefulWidget {
  final BackendChild child;
  final bool isDelegate;

  const BabyCareCard({super.key, required this.child, this.isDelegate = false});

  @override
  State<BabyCareCard> createState() => _BabyCareCardState();
}

class _BabyCareCardState extends State<BabyCareCard> {
  late Future<Map<String, dynamic>> _data;

  static const _quick = [
    ('menyusu', 'Menyusu', Icons.water_drop_outlined, pataraPink),
    ('popok', 'Popok', Icons.baby_changing_station, pataraTeal),
    ('tidur', 'Tidur', Icons.bedtime_outlined, pataraPurple),
    ('tengkurap', 'Tengkurap', Icons.accessibility_new, pataraOrange),
  ];

  // Kategori aktif dari server (diatur admin); null selama belum dimuat.
  Map<String, ActivityCategory>? _active;

  @override
  void initState() {
    super.initState();
    _data = PataraApi.babyCare(widget.child.id);
    PataraApi.formOptions().then((options) {
      if (mounted) setState(() { _active = {for (final item in options.categories) item.key: item}; });
    }).catchError((_) {});
  }

  Future<void> _log(String category) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityFormScreen(
          child: widget.child,
          isDelegate: widget.isDelegate,
          initial: {'category': category},
        ),
      ),
    );
    if (saved == true && mounted) setState(() { _data = PataraApi.babyCare(widget.child.id); });
  }

  String _duration(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60} j ${minutes % 60} mnt' : '$minutes mnt';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PataraCard(child: LinearProgressIndicator());
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null || data['applicable'] != true) {
          return const SizedBox.shrink();
        }
        final values = {
          'menyusu': '${data['feeds']}×',
          'popok': '${data['diapers']}×',
          'tidur': _duration(data['sleep_minutes'] as int),
          'tengkurap': _duration(data['tummy_minutes'] as int),
        };
        final references = (data['references'] as List).cast<Map<String, dynamic>>();
        final due = ((data['due_immunizations'] as List?) ?? const []).cast<Map<String, dynamic>>();
        return PataraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.child_friendly, color: pataraBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Perawatan bayi hari ini', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Delegasi tidak mendapat catat cepat: laporannya lewat formulir lengkap (dengan foto bukti)
              // di tab Aktivitas, jadi di sini hanya ringkasan hari ini.
              Text(
                widget.isDelegate
                    ? 'Ringkasan hari ini dari catatan yang sudah tervalidasi.'
                    : 'Ketuk untuk mencatat. Angka dihitung dari catatan yang sudah tervalidasi.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Nama mengikuti panel admin; kategori yang dinonaktifkan admin tidak bisa dicatat dari sini.
                  for (final (key, defaultLabel, icon, color) in _quick)
                    if ((_active?[key]?.label ?? defaultLabel) case final label)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: widget.isDelegate || (_active != null && !_active!.containsKey(key)) ? null : () => _log(key),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(icon, color: color),
                              const SizedBox(height: 4),
                              FittedBox(
                                child: Text(
                                  values[key]!,
                                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15),
                                ),
                              ),
                              FittedBox(child: Text(label, style: const TextStyle(fontSize: 11))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (final item in references)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '•  ${item['text']} (${item['source']})',
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
              if (due.isNotEmpty) ...[
                const Divider(height: 18),
                Text(
                  'Imunisasi yang jadwal usianya sudah tiba dan belum dicatat: ${due.map((item) => item['label']).join(', ')}.',
                  style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Catat di menu Kesehatan bila sudah diberikan, atau tanyakan jadwalnya ke Posyandu.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
