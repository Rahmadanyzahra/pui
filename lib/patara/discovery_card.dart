import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// TARA Discovery: pola anak yang terbuka setelah cukup catatan, dan misi berikutnya.
class DiscoveryCard extends StatefulWidget {
  final BackendChild child;

  const DiscoveryCard({super.key, required this.child});

  @override
  State<DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<DiscoveryCard> {
  late final Future<Map<String, dynamic>> _data = PataraApi.discovery(widget.child.id);

  static const _icons = {
    'tidur': Icons.bedtime_outlined,
    'makan': Icons.restaurant_outlined,
    'tantrum': Icons.bolt_outlined,
    'favorit': Icons.favorite_outline,
    'rutin': Icons.event_available_outlined,
  };

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
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF311B92), Color(0xFF5E35B1), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.travel_explore, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kenali pola ${widget.child.nama}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${data['unlocked']}/${data['total']} terbuka',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_outlined, color: pataraOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Misi berikutnya: ${(data['mission'] as Map)['text']}',
                        style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final item in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(item['unlocked'] == true ? 0.96 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item['unlocked'] == true ? _icons[item['key']] ?? Icons.insights : Icons.lock_outline,
                        color: item['unlocked'] == true ? pataraPurple : Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['title']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: item['unlocked'] == true ? pataraInk : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (item['unlocked'] == true)
                              Text('${item['insight']}', style: const TextStyle(fontSize: 12.5, height: 1.35))
                            else ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (item['have'] as int) / (item['need'] as int),
                                  minHeight: 6,
                                  color: const Color(0xFFFFD54F),
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item['have']} dari ${item['need']} ${item['unit']}',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text('${data['note']}', style: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.35)),
            ],
          ),
        );
      },
    );
  }
}
