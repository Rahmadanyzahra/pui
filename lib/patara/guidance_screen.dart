import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Saran aktivitas di luar aplikasi (sensori, motorik, bahasa, dan lainnya), panduan makanan
/// dan minuman sesuai usia anak beserta sumber pedomannya, dan saran dari ahli.
class GuidanceScreen extends StatefulWidget {
  final BackendChild child;

  const GuidanceScreen({super.key, required this.child});

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = PataraApi.guidance(widget.child.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Ide Aktivitas & Gizi ${widget.child.nama}', pataraTeal, icon: Icons.lightbulb_outline),
      body: AsyncView<Map<String, dynamic>>(
        future: _data,
        onRetry: () => setState(() { _data = PataraApi.guidance(widget.child.id); }),
        builder: (context, data) {
          final child = data['child'] as Map<String, dynamic>;
          final types = (data['types'] as List).cast<Map<String, dynamic>>();
          final activities = (data['activities'] as List).cast<Map<String, dynamic>>();
          final sources = (data['sources'] as List).cast<Map<String, dynamic>>();
          final nutrition = (data['nutrition'] as List).cast<Map<String, dynamic>>();
          final nutritionTopics = ((data['nutrition_topics'] as List?) ?? const []).cast<Map<String, dynamic>>();
          final advice = ((data['expert_advice'] as List?) ?? const []).cast<Map<String, dynamic>>();
          // Nomor rujukan mengikuti urutan pada daftar sumber di bagian bawah.
          final number = {for (var index = 0; index < sources.length; index++) sources[index]['key']: index + 1};
          String refs(Map<String, dynamic> item) =>
              (item['sources'] as List).map((key) => '[${number[key] ?? '?'}]').join(' ');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PataraCard(
                child: Text(
                  'Usia ${child['age_formatted']} • ${child['category_label']}\n'
                  'Kegiatan berikut dilakukan langsung bersama anak, di luar aplikasi. ${data['safety']}',
                  style: const TextStyle(height: 1.4),
                ),
              ),
              for (final type in types) ...[
                SectionTitle('${type['label']}'),
                for (final item in activities.where((item) => item['type'] == type['key']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PataraCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${item['how']}', style: const TextStyle(height: 1.4)),
                          const SizedBox(height: 4),
                          Text('Sumber ${refs(item)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
              ],
              const SectionTitle('Gerak, layar, dan tidur'),
              _bullets((data['movement'] as List).cast<Map<String, dynamic>>(), refs),
              if (nutritionTopics.isEmpty) ...[
                const SectionTitle('Gizi dan makan'),
                _bullets(nutrition, refs),
              ] else
                for (final topic in nutritionTopics) ...[
                  SectionTitle('${topic['label']}'),
                  _bullets(nutrition.where((item) => item['topic'] == topic['key']).toList(), refs),
                ],
              if (((data['calming'] as List?) ?? const []).isNotEmpty) ...[
                const SectionTitle('Saat anak menangis, rewel, atau tantrum'),
                _bullets((data['calming'] as List).cast<Map<String, dynamic>>(), refs),
              ],
              const SectionTitle('Saran dari ahli'),
              if (advice.isEmpty)
                const PataraCard(
                  child: Text(
                    'Belum ada saran ahli untuk usia ini. Untuk saran yang sesuai kondisi anak, konsultasikan dengan ahli gizi, bidan, atau dokter anak.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                )
              else
                for (final item in advice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PataraCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${item['body']}', style: const TextStyle(height: 1.4)),
                          const SizedBox(height: 6),
                          Text(
                            '${item['topic_label']} • ${item['expert_name']}, ${item['expert_title']}',
                            style: const TextStyle(fontSize: 12, color: pataraTeal, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SectionTitle('Rekap catatan makan'),
              _buildRecap(data['nutrition_recap'] as Map<String, dynamic>),
              const SectionTitle('Sumber'),
              PataraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final source in sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '[${number[source['key']]}] ${source['label']}',
                          style: const TextStyle(fontSize: 12.5, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
              DisclaimerNote('${data['note']}'),
            ],
          );
        },
      ),
    );
  }

  Widget _bullets(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) refs) {
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('•  ${item['text']} ${refs(item)}', style: const TextStyle(height: 1.4)),
            ),
        ],
      ),
    );
  }

  Widget _buildRecap(Map<String, dynamic> recap) {
    final groups = (recap['groups'] as List).cast<Map<String, dynamic>>();
    final days = recap['days'] as int;
    if (recap['enough_data'] != true) {
      return PataraCard(
        child: Text(
          'Belum cukup data: baru ${recap['detailed_meals']} catatan makan dengan isi piring dalam ${recap['period_days']} hari terakhir '
          '(minimal ${recap['minimum_sample']}). Saat mencatat aktivitas Makan, isi porsi dan kelompok pangannya.',
          style: const TextStyle(color: Colors.black54, height: 1.4),
        ),
      );
    }
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${recap['detailed_meals']} catatan makan pada $days hari (dari ${recap['period_days']} hari terakhir)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text('${group['label']}', style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: days == 0 ? 0 : (group['days'] as int) / days,
                        minHeight: 8,
                        color: pataraTeal,
                        backgroundColor: pataraTeal.withOpacity(0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${group['days']}/$days hari', style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          for (final note in (recap['notes'] as List).cast<String>())
            Text('•  $note', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 6),
          const Text(
            'Rekap ini hanya menghitung apa yang dicatat dan tidak menilai status gizi anak.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
