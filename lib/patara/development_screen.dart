import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Development Monitoring: indikator perkembangan sesuai usia pada empat aspek.
class DevelopmentScreen extends StatefulWidget {
  final BackendChild child;

  const DevelopmentScreen({super.key, required this.child});

  @override
  State<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends State<DevelopmentScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = PataraApi.development(widget.child.id);
  }

  void _reload() => setState(() { _data = PataraApi.development(widget.child.id); });

  Future<void> _setStatus(Object standardId, String status) async {
    try {
      await PataraApi.saveDevelopmentItem(widget.child.id, standardId, status);
      final fresh = await PataraApi.development(widget.child.id);
      if (mounted) setState(() { _data = Future.value(fresh); });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Perkembangan ${widget.child.nama}', pataraOrange, icon: Icons.trending_up),
      body: AsyncView<Map<String, dynamic>>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) {
          final child = data['child'] as Map<String, dynamic>;
          final aspects = (data['aspects'] as List).cast<Map<String, dynamic>>();
          final statuses = (data['statuses'] as List).cast<Map<String, dynamic>>();
          final ideas = (data['stimulation_suggestions'] as List).cast<String>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PataraCard(
                child: Text(
                  'Usia ${child['age_formatted']} • ${child['category_label']}\n'
                  'Tandai setiap indikator sesuai yang Anda amati sehari-hari.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
              for (final aspect in aspects) ...[
                SectionTitle(
                  '${aspect['label']}',
                  trailing: Text(
                    aspect['total'] == 0 ? '' : '${aspect['tercapai']}/${aspect['total']} terlihat',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                if ((aspect['items'] as List).isEmpty)
                  const PataraCard(child: Text('Standar untuk usia ini belum tersedia.'))
                else
                  for (final item in (aspect['items'] as List).cast<Map<String, dynamic>>())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PataraCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['text']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final status in statuses)
                                  ChoiceChip(
                                    label: Text('${status['label']}'),
                                    selected: item['status'] == status['key'],
                                    onSelected: (_) => _setStatus(item['standard_id'] as Object, '${status['key']}'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              if (ideas.isNotEmpty) ...[
                const SectionTitle('Ide stimulasi sesuai usia'),
                PataraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final idea in ideas) Text('•  $idea', style: const TextStyle(height: 1.5))],
                  ),
                ),
              ],
              DisclaimerNote('${data['disclaimer']}'),
            ],
          );
        },
      ),
    );
  }
}
