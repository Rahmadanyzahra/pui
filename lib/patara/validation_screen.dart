import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'patara_api.dart';
import 'patara_ui.dart';

/// Laporan aktivitas dari Delegasi yang menunggu validasi Orang Tua.
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  late Future<(FormOptions, List<Map<String, dynamic>>)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(FormOptions, List<Map<String, dynamic>>)> _load() async =>
      (await PataraApi.formOptions(), await PataraApi.pendingValidations());

  void _reload() => setState(() { _data = _load(); });

  Future<void> _decide(Map<String, dynamic> item, bool confirm) async {
    var note = '';
    if (!confirm) {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tidak sesuai'),
          content: TextField(
            controller: controller,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Catatan untuk Delegasi (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Tandai tidak sesuai'),
            ),
          ],
        ),
      );
      if (result == null) return;
      note = result;
    }
    try {
      await PataraApi.validateActivity('${item['id']}', confirm: confirm, note: note);
      if (!mounted) return;
      showMessage(
        context,
        confirm
            ? 'Laporan dinyatakan sesuai dan masuk ke catatan ${item['child_name']}.'
            : 'Laporan ditandai tidak sesuai dan tidak dihitung dalam analisis.',
      );
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  void _showPhoto(String path) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: FutureBuilder<Uint8List>(
          future: PataraApi.photoBytes(path),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Validasi Laporan Delegasi', pataraOrange, icon: Icons.fact_check_outlined),
      body: AsyncView<(FormOptions, List<Map<String, dynamic>>)>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) {
          final (options, items) = data;
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.verified_outlined,
              title: 'Semua laporan sudah divalidasi',
              message: 'Laporan aktivitas baru dari Delegasi akan muncul di sini dan sebagai notifikasi.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildItem(options, items[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(FormOptions options, Map<String, dynamic> item) {
    final at = DateTime.parse('${item['event_at']}').toLocal();
    final fussy = (item['fussy_level'] as num?)?.toInt();
    final tantrum = (item['tantrum_count'] as num?)?.toInt() ?? 0;
    final details = <String>[
      if (item['mood_before'] != null || item['mood_after'] != null)
        'Mood: ${moodEmoji[item['mood_before']] ?? '–'} → ${moodEmoji[item['mood_after']] ?? '–'}',
      if (fussy != null && fussy < options.fussyLevels.length) options.fussyLevels[fussy],
      if (tantrum > 0) 'Tantrum $tantrum×',
      if (item['status'] == 'tidak_selesai') 'Tidak selesai',
      if (options.mealLabel(item['meal'] as Map<String, dynamic>?).isNotEmpty)
        options.mealLabel(item['meal'] as Map<String, dynamic>?),
    ];
    final duration = durationEvidence(
      (item['duration_minutes'] as num?)?.toInt(),
      item['duration_source'] as String?,
      startedAt: DateTime.tryParse('${item['started_at']}')?.toLocal(),
      endedAt: DateTime.tryParse('${item['ended_at']}')?.toLocal(),
    );
    final timed = item['duration_source'] == 'timer';
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: pataraPink.withOpacity(0.12),
                child: Icon(options.categoryIcon('${item['category']}'), color: pataraPink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['category_label']} • ${item['child_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      'Dilaporkan ${item['performer_name']} • ${formatDate(at)} ${formatTime(at)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ('${item['description']}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${item['description']}'),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(details.join(' • '), style: const TextStyle(fontSize: 12.5, color: pataraInk)),
          ],
          if (duration.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  timed ? Icons.verified_outlined : Icons.help_outline,
                  size: 16,
                  color: timed ? const Color(0xFF2E7D32) : pataraOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    duration,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: timed ? const Color(0xFF2E7D32) : pataraOrange,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (item['photo_path'] != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => _showPhoto('${item['photo_path']}'),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Lihat foto bukti'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _decide(item, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Sesuai'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _decide(item, false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tidak sesuai'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
