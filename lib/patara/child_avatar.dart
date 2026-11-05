import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_ui.dart';

/// Foto profil anak. Bila anak belum punya foto, yang tampil adalah karakter hewannya.
class ChildAvatar extends StatefulWidget {
  final String childId;
  final double size;
  final Color? background;

  const ChildAvatar({super.key, required this.childId, this.size = 60, this.background});

  // Foto yang sudah diambil disimpan selama aplikasi terbuka; null berarti anak itu belum punya foto.
  static final Map<String, Uint8List?> _cache = {};
  static final ValueNotifier<int> _version = ValueNotifier(0);

  /// Dipanggil setelah foto anak diganti agar semua layar memuat foto barunya.
  static void refresh(String childId) {
    _cache.remove(childId);
    _version.value++;
  }

  @override
  State<ChildAvatar> createState() => _ChildAvatarState();
}

class _ChildAvatarState extends State<ChildAvatar> {
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    ChildAvatar._version.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(ChildAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) _load();
  }

  @override
  void dispose() {
    ChildAvatar._version.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.childId;
    if (!ChildAvatar._cache.containsKey(id)) {
      try {
        final response = await BackendApiService.send('GET', '/children/$id/photo');
        ChildAvatar._cache[id] = response.bodyBytes;
      } catch (_) {
        // Belum ada foto (atau server tidak terjangkau): pakai karakter hewan.
        ChildAvatar._cache[id] = null;
      }
    }
    if (mounted && id == widget.childId) setState(() { _photo = ChildAvatar._cache[id]; });
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    if (photo == null) {
      return KidMascot(emoji: mascotFor(widget.childId), size: widget.size, background: widget.background);
    }
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
      ),
    );
  }
}
