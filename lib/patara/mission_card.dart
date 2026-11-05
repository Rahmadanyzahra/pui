import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_ui.dart';

/// Gamifikasi pencatatan: misi harian, rangkaian hari mencatat, dan tingkat pencatat.
/// Ringkas dalam satu baris; diketuk untuk melihat misinya. Tidak tampil bagi kelompok kontrol.
class MissionCard extends StatefulWidget {
  final BackendChild child;

  const MissionCard({super.key, required this.child});

  @override
  State<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<MissionCard> {
  Map<String, dynamic>? _data;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await BackendApiService.requestJson('GET', '/api/gamification/${widget.child.id}') as Map<String, dynamic>;
      if (mounted) setState(() { _data = data; });
    } catch (_) {
      // Tanpa sambungan, kartu misi cukup tidak tampil; pencatatan tetap bisa dilakukan.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null || data['enabled'] != true) return const SizedBox.shrink();
    final missions = (data['missions'] as List).cast<Map<String, dynamic>>();
    final done = data['missions_done'] as int;
    final streak = data['streak_days'] as int;
    final level = data['level'] as Map<String, dynamic>;
    final week = (data['week'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF3C4), Color(0xFFFFE0B2)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() { _open = !_open; });
            if (_open) _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Cincin misi terisi pelan-pelan dari kosong sampai jumlah misi yang selesai.
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: missions.isEmpty ? 0 : done / missions.length),
                            duration: const Duration(milliseconds: 1100),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => CircularProgressIndicator(
                              value: value,
                              strokeWidth: 5,
                              color: const Color(0xFFEF6C00),
                              backgroundColor: Colors.white,
                            ),
                          ),
                          Text('$done/${missions.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['today_complete'] == true ? 'Misi hari ini selesai!' : 'Misi mencatat hari ini',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                          Text(
                            '${level['title']} • ${streak == 0 ? 'mulai rangkaian hari ini' : '$streak hari berturut-turut'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: pataraInk),
                          ),
                        ],
                      ),
                    ),
                    if (streak > 0) Text('🔥 $streak', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, color: pataraInk),
                  ],
                ),
                if (_open) ...[
                  const SizedBox(height: 10),
                  for (final mission in missions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            mission['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 20,
                            color: mission['done'] == true ? const Color(0xFF43A047) : Colors.black38,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${mission['title']}',
                              style: TextStyle(
                                fontSize: 13.5,
                                decoration: mission['done'] == true ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('7 hari: ', style: TextStyle(fontSize: 12.5)),
                      for (final day in week)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: day['logged'] == true ? const Color(0xFFEF6C00) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    level['next_title'] == null
                        ? 'Tingkat tertinggi tercapai: ${data['complete_days_30']} hari lengkap dalam 30 hari.'
                        : '${data['complete_days_30']} dari ${level['next_at']} hari lengkap menuju ${level['next_title']}.',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('${data['note']}', style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
