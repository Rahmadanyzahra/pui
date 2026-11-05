import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_ui.dart';

/// Parenting Experiment: mencoba satu kebiasaan beberapa hari, lalu melihat angka sebelum dan selama percobaan.
class ExperimentCard extends StatefulWidget {
  final BackendChild child;

  const ExperimentCard({super.key, required this.child});

  @override
  State<ExperimentCard> createState() => _ExperimentCardState();
}

class _ExperimentCardState extends State<ExperimentCard> {
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async =>
      await BackendApiService.requestJson('GET', '/api/experiments/${widget.child.id}') as Map<String, dynamic>;

  Future<void> _send(String method, String path, {Map<String, dynamic>? body}) async {
    try {
      await BackendApiService.send(method, path, body: body);
      if (mounted) setState(() { _data = _load(); });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const PataraCard(child: LinearProgressIndicator());
        }
        if (snapshot.hasError || data == null) return const SizedBox.shrink();
        final active = data['active'] as Map<String, dynamic>?;
        final history = (data['history'] as List).cast<Map<String, dynamic>>();
        final templates = (data['templates'] as List).cast<Map<String, dynamic>>();
        return PataraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_outlined, color: pataraTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Percobaan kebiasaan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (active != null) ...[
                Text('${active['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (active['day'] as int) / (active['days'] as int),
                    minHeight: 7,
                    color: pataraTeal,
                    backgroundColor: pataraTeal.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${active['summary']}', style: const TextStyle(fontSize: 13, height: 1.4)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _send('DELETE', '/api/experiments/${widget.child.id}/${active['id']}'),
                    child: const Text('Batalkan percobaan'),
                  ),
                ),
              ] else ...[
                const Text(
                  'Pilih satu kebiasaan untuk dicoba. Setelah selesai, catatan sebelum dan selama percobaan dibandingkan.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 8),
                for (final template in templates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _send(
                        'POST',
                        '/api/experiments/${widget.child.id}',
                        body: {'template': template['key']},
                      ),
                      child: Text(
                        '${template['title']} (${template['days']} hari)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
              if (history.isNotEmpty) ...[
                const Divider(height: 18),
                const Text('Hasil percobaan terakhir', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${history.first['title']}: ${history.first['summary']}',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '${history.first['note']}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
