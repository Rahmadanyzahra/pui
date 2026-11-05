import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_ui.dart';

/// Pengumuman dari admin di beranda. Tidak tampil bila tidak ada pengumuman atau server tidak terjangkau.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  String? _message;

  @override
  void initState() {
    super.initState();
    BackendApiService.requestJson('GET', '/api/announcement')
        .then((data) {
          final message = (data as Map<String, dynamic>)['message'] as String?;
          if (mounted && message != null && message.isNotEmpty) setState(() { _message = message; });
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: pataraOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pengumuman', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(message, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
