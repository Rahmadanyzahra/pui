import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'parent_shell.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

class _ChatMessage {
  final bool fromUser;
  final String text;

  /// Draf catatan aktivitas yang ditangkap dari cerita orang tua, beserta anak yang dimaksud.
  final Map<String, dynamic>? draft;
  final BackendChild? child;
  bool? saved;

  _ChatMessage(this.fromUser, this.text, {this.draft, this.child});
}

/// AI Chat: informasi parenting umum, penjelasan hasil monitoring, dan pencatatan
/// aktivitas dari cerita orang tua. Bukan diagnosis.
class ChatTab extends StatefulWidget {
  final ChildrenController controller;

  const ChatTab({super.key, required this.controller});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  FormOptions? _options;
  bool _sending = false;

  static const _suggestions = [
    'Ide aktivitas sesuai usia anak',
    'Tips agar anak mudah tidur',
    'Cara menghadapi tantrum',
    'Jelaskan hasil monitoring',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final child = widget.controller.selected;
    final history = [
      for (final message in _messages)
        {'role': message.fromUser ? 'user' : 'assistant', 'content': message.text},
    ];
    setState(() {
      _messages.add(_ChatMessage(true, text));
      _sending = true;
    });
    _ChatMessage reply;
    try {
      final result = await PataraApi.chat(text, child?.id, history: history);
      if (result.draft != null) _options ??= await PataraApi.formOptions();
      reply = _ChatMessage(false, result.text, draft: result.draft, child: child);
    } catch (error) {
      reply = _ChatMessage(false, 'Pesan belum terkirim: ${errorText(error)}');
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _sending = false;
    });
    _scrollToEnd();
  }

  Future<void> _saveDraft(_ChatMessage message) async {
    final draft = message.draft!;
    try {
      await PataraApi.saveActivity(
        childId: message.child!.id,
        category: '${draft['category']}',
        data: draft,
      );
      if (!mounted) return;
      setState(() { message.saved = true; });
      showMessage(context, 'Catatan aktivitas tersimpan.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _editDraft(_ChatMessage message) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityFormScreen(child: message.child!, initial: message.draft),
      ),
    );
    if (saved == true && mounted) setState(() { message.saved = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => widget.controller.children.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ChildSelector(controller: widget.controller),
                ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              if (_messages.isEmpty) ...[
                const PataraCard(
                  child: Text(
                    'Tanyakan seputar parenting, atau ceritakan kegiatan anak dengan bahasa sehari-hari, '
                    'misalnya "tadi pagi makannya lahap". Cerita seperti itu saya ubah menjadi draf catatan yang Anda periksa dulu sebelum disimpan.\n\n'
                    'Asisten ini tidak mendiagnosis dan tidak menggantikan dokter atau psikolog.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final suggestion in _suggestions)
                      ActionChip(label: Text(suggestion), onPressed: () => _send(suggestion)),
                  ],
                ),
              ],
              for (final message in _messages) ...[
                Align(
                  alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: message.fromUser ? pataraPink : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(color: message.fromUser ? Colors.white : pataraInk, height: 1.4),
                    ),
                  ),
                ),
                if (message.draft != null && message.child != null) _buildDraft(message),
              ],
              if (_sending)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Tulis pertanyaan atau cerita...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send, color: pataraPink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu konfirmasi: orang tua memeriksa hasil tangkapan AI sebelum disimpan.
  Widget _buildDraft(_ChatMessage message) {
    final draft = message.draft!;
    final options = _options;
    final at = DateTime.tryParse('${draft['event_at']}')?.toLocal();
    final fussy = (draft['fussy_level'] as num?)?.toInt();
    final tantrum = (draft['tantrum_count'] as num?)?.toInt() ?? 0;
    final rows = <(String, String)>[
      ('Anak', message.child!.nama),
      ('Aktivitas', '${draft['category_label']}'),
      if (at != null) ('Waktu', '${formatDate(at)} pukul ${formatTime(at)}'),
      if ('${draft['description']}'.isNotEmpty) ('Deskripsi', '${draft['description']}'),
      if (draft['mood_before'] != null)
        ('Mood sebelum', options?.moodLabel(draft['mood_before'] as String?) ?? '${draft['mood_before']}'),
      if (draft['mood_after'] != null)
        ('Mood setelah', options?.moodLabel(draft['mood_after'] as String?) ?? '${draft['mood_after']}'),
      if (fussy != null && options != null && fussy < options.fussyLevels.length) ('Rewel', options.fussyLevels[fussy]),
      if (tantrum > 0) ('Tantrum', '$tantrum kali'),
      if (draft['status'] == 'tidak_selesai') ('Status', 'Tidak selesai'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: PataraCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: pataraPink, size: 20),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Draf catatan aktivitas', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    ),
                    Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (message.saved == true)
              const Text('✓ Tersimpan di catatan aktivitas', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700))
            else if (message.saved == false)
              const Text('Draf diabaikan', style: TextStyle(color: Colors.black54))
            else
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(onPressed: () => _saveDraft(message), child: const Text('Simpan')),
                  OutlinedButton(onPressed: () => _editDraft(message), child: const Text('Ubah')),
                  TextButton(
                    onPressed: () => setState(() { message.saved = false; }),
                    child: const Text('Abaikan'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
