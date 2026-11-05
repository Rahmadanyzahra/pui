import 'package:flutter/material.dart';

import '../features/login_screen.dart';
import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Menahan aplikasi di layar persetujuan sampai pengguna menyetujui ikut serta dalam penelitian.
class ConsentGate extends StatefulWidget {
  final Widget child;

  const ConsentGate({super.key, required this.child});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  late Future<Map<String, dynamic>> _consent;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _consent = PataraApi.consent();
  }

  @override
  Widget build(BuildContext context) {
    if (_agreed) return widget.child;
    return FutureBuilder<Map<String, dynamic>>(
      future: _consent,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: EmptyView(
              icon: Icons.cloud_off,
              title: 'Data belum dapat dimuat',
              message: errorText(snapshot.error!),
              actionLabel: 'Coba lagi',
              onAction: () => setState(() { _consent = PataraApi.consent(); }),
            ),
          );
        }
        final data = snapshot.data!;
        if (data['agreed'] == true) return widget.child;
        return ConsentScreen(
          document: data['document'] as Map<String, dynamic>,
          onAgreed: () => setState(() { _agreed = true; }),
        );
      },
    );
  }
}

/// Lembar persetujuan ikut serta dalam penelitian. Tanpa [onAgreed], layar hanya untuk dibaca ulang.
class ConsentScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  final String? agreedAt;
  final VoidCallback? onAgreed;

  const ConsentScreen({super.key, required this.document, this.agreedAt, this.onAgreed});

  /// Membuka lembar persetujuan dari menu Akun.
  static Future<void> open(BuildContext context) async {
    try {
      final data = await PataraApi.consent();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConsentScreen(
            document: data['document'] as Map<String, dynamic>,
            agreedAt: data['agreed_at'] as String?,
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
    }
  }

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _agree() async {
    setState(() { _busy = true; });
    try {
      await PataraApi.agreeConsent('${widget.document['version']}');
      widget.onAgreed!();
    } catch (error) {
      if (mounted) {
        showMessage(context, errorText(error));
        setState(() { _busy = false; });
      }
    }
  }

  Future<void> _decline() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Tidak setuju?',
      message: 'Tanpa persetujuan, aplikasi tidak dapat dipakai. Anda akan keluar dari akun.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed) return;
    try {
      await BackendApiService.send('POST', '/api/logout');
    } catch (_) {
      // Sesi lokal tetap dihapus walau server tidak terjangkau.
    }
    await BackendApiService.clearSession(clearPassword: true, clearEmail: true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final points = (document['points'] as List).cast<Map<String, dynamic>>();
    final asking = widget.onAgreed != null;
    return Scaffold(
      appBar: sectionAppBar(
        'Persetujuan Penelitian',
        pataraPurple,
        icon: Icons.verified_user_outlined,
        automaticallyImplyLeading: !asking,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${document['title']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PataraCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${point['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${point['text']}', style: const TextStyle(height: 1.4)),
                  ],
                ),
              ),
            ),
          if ('${document['role_note']}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${document['role_note']}', style: const TextStyle(height: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Kontak peneliti: ${document['contact']}', style: const TextStyle(color: Colors.black54, height: 1.4)),
          ),
          if (!asking)
            DisclaimerNote(
              widget.agreedAt == null
                  ? 'Versi dokumen ${document['version']}.'
                  : 'Anda menyetujui dokumen versi ${document['version']} pada ${formatDate(DateTime.parse(widget.agreedAt!).toLocal())}.',
            ),
          if (asking) ...[
            CheckboxListTile(
              value: _checked,
              onChanged: (value) => setState(() { _checked = value ?? false; }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text('${document['statement']}'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _checked && !_busy ? _agree : null,
                child: const Text('Setuju dan lanjutkan'),
              ),
            ),
            TextButton(onPressed: _busy ? null : _decline, child: const Text('Saya tidak setuju')),
          ],
        ],
      ),
    );
  }
}
