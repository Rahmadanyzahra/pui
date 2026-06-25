import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';

class AiChatScreen extends StatefulWidget {
  final int? childId;
  final String? childName;
  final Color? themeColor;

  const AiChatScreen({
    super.key,
    this.childId,
    this.childName,
    this.themeColor,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  Color get _primary => widget.themeColor ?? const Color(0xFFF06292);

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        role: 'assistant',
        text:
            'Halo! Saya Patara AI, asisten parenting kamu 👋\n'
            'Tanya apa saja tentang perkembangan anak, solusi perilaku, atau tips pengasuhan!',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _history {
    return _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    _controller.clear();
    final historySnapshot = List<Map<String, String>>.from(_history);

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final reply = await BackendApiService.sendAiChat(
        message: text,
        childId: widget.childId,
        history: historySnapshot,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: reply));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Provide mock response if backend fails
      final mockReplies = [
        'Sebagai AI parenting, saya sarankan untuk selalu mendukung perkembangan anak dengan kasih sayang dan komunikasi yang baik.',
        'Anak-anak belajar terbaik melalui pengalaman langsung. Coba libatkan mereka dalam kegiatan sehari-hari.',
        'Penting untuk memberikan pujian atas usaha anak, bukan hanya hasil akhir.',
        'Jika anak mengalami kesulitan, dengarkan dulu sebelum memberikan saran.',
        'Konsistensi dalam aturan rumah tangga membantu anak merasa aman dan terstruktur.',
      ];
      final mockReply = mockReplies[text.length % mockReplies.length];
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: mockReply));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        const _ChatMessage(
          role: 'assistant',
          text: 'Percakapan direset. Ada yang ingin kamu tanyakan?',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patara AI',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (widget.childName != null)
              Text(
                'Konteks: ${widget.childName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              )
            else
              const Text(
                'Asisten parenting cerdas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Hapus percakapan',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _TypingBubble(color: _primary);
                }
                return _MessageBubble(
                  message: _messages[index],
                  themeColor: _primary,
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            loading: _loading,
            themeColor: _primary,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;

  const _ChatMessage({required this.role, required this.text});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final Color themeColor;

  const _MessageBubble({required this.message, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: themeColor.withOpacity(0.15),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: themeColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? themeColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF212121),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final Color color;

  const _TypingBubble({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.smart_toy_outlined, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: color, delay: 0),
                const SizedBox(width: 4),
                _Dot(color: color, delay: 150),
                const SizedBox(width: 4),
                _Dot(color: color, delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final int delay;

  const _Dot({required this.color, required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final Color themeColor;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.themeColor,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !loading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Tanya tentang parenting...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: loading ? Colors.grey.shade400 : themeColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: loading ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
