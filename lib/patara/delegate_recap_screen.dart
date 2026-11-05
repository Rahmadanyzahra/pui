import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'patara_api.dart';
import 'patara_ui.dart';

/// Kartu kinerja satu Delegasi pada satu periode; dipakai juga di Laporan Bulanan.
class DelegatePerformanceCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const DelegatePerformanceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final accuracy = item['accuracy_percent'] as int?;
    final categories = (item['by_category'] as List).cast<Map<String, dynamic>>();
    final notes = (item['rejection_notes'] as List).cast<String>();
    final childName = item['child_name'];
    final reports = (item['reports'] as List? ?? const []).cast<Map<String, dynamic>>();
    final timerReports = (item['timer_reports'] as num?)?.toInt() ?? 0;
    final timerMinutes = (item['timer_minutes'] as num?)?.toInt() ?? 0;
    final manualReports = (item['manual_duration_reports'] as num?)?.toInt() ?? 0;
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: pataraPurple.withOpacity(0.14),
                child: const Icon(Icons.badge_outlined, color: pataraPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (childName != null)
                      Text('Mendampingi $childName', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Laporan', value: '${item['total_reports']}')),
              Expanded(child: StatTile(label: 'Hari aktif', value: '${item['active_days']}')),
              Expanded(child: StatTile(label: 'Ketepatan', value: accuracy == null ? '–' : '$accuracy%')),
            ],
          ),
          const SizedBox(height: 12),
          if (accuracy != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: accuracy / 100,
                minHeight: 10,
                color: const Color(0xFF43A047),
                backgroundColor: const Color(0xFFE53935).withOpacity(0.25),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${item['confirmed']} sesuai • ${item['rejected']} tidak sesuai • ${item['pending']} menunggu validasi',
            style: const TextStyle(fontSize: 13, color: pataraInk),
          ),
          Text(
            '${item['with_description']} laporan berdeskripsi • ${item['with_photo']} dengan foto bukti',
            style: const TextStyle(fontSize: 13, color: pataraInk),
          ),
          if (timerReports > 0 || manualReports > 0)
            Text(
              '$timerReports laporan dengan timer server (${formatDuration(timerMinutes)}) • $manualReports durasi diisi manual',
              style: const TextStyle(fontSize: 13, color: pataraInk),
            ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in categories)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: pataraPink.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${category['label']} ${category['count']}×', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Catatan Orang Tua pada laporan yang tidak sesuai:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            for (final note in notes) Text('•  $note', style: const TextStyle(fontSize: 12.5)),
          ],
          if (reports.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Rincian ${reports.length} laporan, foto, dan validasi',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                children: [for (final report in reports) _buildReport(context, report)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReport(BuildContext context, Map<String, dynamic> report) {
    final at = DateTime.parse('${report['event_at']}').toLocal();
    final note = '${report['validation_note'] ?? ''}';
    final (label, color) = switch (report['validation_status']) {
      'pending' => ('Menunggu validasi', pataraOrange),
      'rejected' => (note.isEmpty ? 'Tidak sesuai' : 'Tidak sesuai: $note', const Color(0xFFC62828)),
      _ => ('Sesuai', const Color(0xFF2E7D32)),
    };
    final duration = durationEvidence(
      (report['duration_minutes'] as num?)?.toInt(),
      report['duration_source'] as String?,
      startedAt: DateTime.tryParse('${report['started_at']}')?.toLocal(),
      endedAt: DateTime.tryParse('${report['ended_at']}')?.toLocal(),
    );
    final photoPath = report['photo_path'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report['category_label']} • ${formatDate(at)} ${formatTime(at)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if ('${report['description']}'.isNotEmpty)
                  Text('${report['description']}', style: const TextStyle(fontSize: 12.5)),
                if (duration.isNotEmpty) Text(duration, style: const TextStyle(fontSize: 12, color: pataraInk)),
                Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (photoPath != null)
            IconButton(
              tooltip: 'Lihat foto bukti',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: FutureBuilder<Uint8List>(
                    future: PataraApi.photoBytes(photoPath),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(padding: EdgeInsets.all(24), child: Text('Foto sudah tidak tersedia.'));
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.contain);
                    },
                  ),
                ),
              ),
              icon: const Icon(Icons.image_outlined, color: pataraPink),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Tooltip(message: 'Tanpa foto bukti', child: Icon(Icons.hide_image_outlined, color: Colors.black26)),
            ),
        ],
      ),
    );
  }
}

/// Rekap bulanan kinerja Delegasi sebagai bahan evaluasi Orang Tua.
class DelegateRecapScreen extends StatefulWidget {
  const DelegateRecapScreen({super.key});

  @override
  State<DelegateRecapScreen> createState() => _DelegateRecapScreenState();
}

class _DelegateRecapScreenState extends State<DelegateRecapScreen> {
  late DateTime _month;
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _data = PataraApi.delegateRecap(monthKey(_month));
  }

  void _select(DateTime month) => setState(() {
    _month = month;
    _data = PataraApi.delegateRecap(monthKey(month));
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: sectionAppBar('Rekap Kinerja Delegasi', pataraPurple, icon: Icons.leaderboard_outlined),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<DateTime>(
              initialValue: _month,
              decoration: const InputDecoration(labelText: 'Periode', border: OutlineInputBorder()),
              items: [
                for (var offset = 0; offset < 12; offset++)
                  DropdownMenuItem(
                    value: DateTime(now.year, now.month - offset),
                    child: Text(formatMonth(DateTime(now.year, now.month - offset))),
                  ),
              ],
              onChanged: (month) => month == null ? null : _select(month),
            ),
          ),
          Expanded(
            child: AsyncView<Map<String, dynamic>>(
              future: _data,
              onRetry: () => _select(_month),
              builder: (context, data) {
                final items = (data['items'] as List).cast<Map<String, dynamic>>();
                if (items.isEmpty) {
                  return EmptyView(
                    icon: Icons.assignment_ind_outlined,
                    title: 'Belum ada laporan Delegasi',
                    message: 'Pada ${data['label']} belum ada aktivitas yang dicatat oleh Delegasi.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in items) ...[
                      DelegatePerformanceCard(item: item),
                      const SizedBox(height: 12),
                    ],
                    const DisclaimerNote(
                      'Ketepatan dihitung dari laporan yang sudah Anda validasi: laporan "sesuai" dibagi seluruh laporan yang diputuskan. '
                      'Durasi "timer server" dihitung dari jam Delegasi menekan Mulai sampai laporan dikirim; durasi manual hanya pengakuan Delegasi. '
                      'Foto bukti dihapus otomatis setelah 30 hari. Rekap ini juga tercantum di Laporan Bulanan.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
