import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';
import 'delegate_recap_screen.dart';
import 'patara_ui.dart';

/// Kelola Delegasi: buat undangan (token), setujui permintaan, dan cabut akses.
class DelegationScreen extends StatefulWidget {
  const DelegationScreen({super.key});

  @override
  State<DelegationScreen> createState() => _DelegationScreenState();
}

class _DelegationScreenState extends State<DelegationScreen> {
  late Future<List<BackendConnectionToken>> _tokens;

  @override
  void initState() {
    super.initState();
    _tokens = BackendApiService.listConnectionTokens();
  }

  void _reload() => setState(() { _tokens = BackendApiService.listConnectionTokens(); });

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      showMessage(context, success);
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _invite() async {
    List<BackendChild> children;
    try {
      children = await BackendApiService.getChildren();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
      return;
    }
    if (!mounted) return;
    if (children.isEmpty) {
      showMessage(context, 'Tambahkan data anak terlebih dahulu.');
      return;
    }
    final draft = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteForm(children: children),
    );
    if (draft == null) return;
    try {
      final token = await BackendApiService.generateConnectionToken(
        childId: draft.$1,
        inviteeName: draft.$2,
        inviteeContact: draft.$3,
      );
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Token undangan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(token, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'Berikan token ini kepada Delegasi. Ia memasukkannya di aplikasi, lalu Anda menyetujui permintaannya di halaman ini. Token berlaku 30 hari.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salin token'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar(
        'Delegasi',
        pataraBlue,
        icon: Icons.group_outlined,
        actions: [
          IconButton(
            tooltip: 'Rekap kinerja Delegasi',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DelegateRecapScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add),
        label: const Text('Undang Delegasi'),
      ),
      body: AsyncView<List<BackendConnectionToken>>(
        future: _tokens,
        onRetry: _reload,
        builder: (context, tokens) {
          if (tokens.isEmpty) {
            return const EmptyView(
              icon: Icons.group_outlined,
              title: 'Belum ada Delegasi',
              message:
                  'Undang pengasuh atau anggota keluarga untuk membantu mencatat aktivitas satu anak. Delegasi tidak dapat mengubah data anak atau membuka laporan.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: tokens.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildItem(tokens[index]),
          );
        },
      ),
    );
  }

  Widget _buildItem(BackendConnectionToken item) {
    final waiting = item.status == 'PENDING' && item.isUsed;
    final (label, color) = switch (item.status) {
      'ACTIVE' => ('Aktif', const Color(0xFF2E7D32)),
      'REJECTED' => ('Ditolak', const Color(0xFFC62828)),
      'REVOKED' => ('Akses dicabut', Colors.black54),
      _ => waiting ? ('Menunggu persetujuan Anda', const Color(0xFFEF6C00)) : ('Token belum dipakai', Colors.black54),
    };
    final name = item.delegateName ?? item.inviteeName ?? 'Delegasi';
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('Anak: ${item.childName ?? '-'}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          if (item.status == 'PENDING' && !item.isUsed)
            Row(
              children: [
                Expanded(child: SelectableText(item.token, style: const TextStyle(fontSize: 13))),
                IconButton(
                  tooltip: 'Salin token',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.token));
                    showMessage(context, 'Token disalin.');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
          if (waiting)
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _run(
                    () => BackendApiService.decideDelegationRequest(token: item.token, approve: true),
                    '$name sekarang dapat mencatat aktivitas.',
                  ),
                  child: const Text('Setujui'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _run(
                    () => BackendApiService.decideDelegationRequest(token: item.token, approve: false),
                    'Permintaan ditolak.',
                  ),
                  child: const Text('Tolak'),
                ),
              ],
            ),
          if (item.status == 'ACTIVE')
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await confirmDialog(
                    context,
                    title: 'Cabut akses $name?',
                    message: 'Delegasi tidak lagi dapat melihat atau mencatat aktivitas anak.',
                    confirmLabel: 'Cabut',
                  );
                  if (confirmed) {
                    await _run(() => BackendApiService.revokeDelegation(item.token), 'Akses $name dicabut.');
                  }
                },
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Cabut akses'),
              ),
            ),
          // Delegasi yang aksesnya sudah berakhir boleh dihapus dari daftar; catatan anak tidak ikut terhapus.
          if (item.status == 'REVOKED' || item.status == 'REJECTED')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final confirmed = await confirmDialog(
                    context,
                    title: 'Hapus $name dari daftar?',
                    message:
                        'Data Delegasi ini (nama, kontak, dan token) dihapus dari daftar Anda. Catatan aktivitas anak yang pernah ia buat tetap tersimpan.',
                    confirmLabel: 'Hapus',
                  );
                  if (confirmed) {
                    await _run(
                      () => BackendApiService.send('DELETE', '/tokens/${Uri.encodeComponent(item.token)}'),
                      '$name dihapus dari daftar.',
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus dari daftar'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteForm extends StatefulWidget {
  final List<BackendChild> children;

  const _InviteForm({required this.children});

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  late String _childId = widget.children.first.id;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Undang Delegasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _childId,
              decoration: const InputDecoration(labelText: 'Anak yang diberi akses', border: OutlineInputBorder()),
              items: [
                for (final child in widget.children) DropdownMenuItem(value: child.id, child: Text(child.nama)),
              ],
              onChanged: (value) => setState(() { _childId = value ?? _childId; }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama Delegasi', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email atau nomor HP akun Delegasi',
                helperText: 'Token hanya bisa dipakai oleh akun Delegasi dengan kontak ini.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty || _contact.text.trim().isEmpty) {
                    showMessage(context, 'Isi nama dan kontak Delegasi.');
                    return;
                  }
                  Navigator.of(context).pop((_childId, _name.text.trim(), _contact.text.trim()));
                },
                child: const Text('Buat Token'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
