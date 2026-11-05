import 'dart:async';

import 'package:flutter/material.dart';

import 'app_entry_screen.dart';
import '../patara/patara_ui.dart';
import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';

class JoinParentTokenScreen extends StatefulWidget {
  final String roleLabel;

  const JoinParentTokenScreen({super.key, required this.roleLabel});

  @override
  State<JoinParentTokenScreen> createState() => _JoinParentTokenScreenState();
}

class _JoinParentTokenScreenState extends State<JoinParentTokenScreen> {
  final _tokenController = TextEditingController();
  Future<BackendConnectionStatus>? _statusFuture;
  BackendDelegationInvitation? _invitation;
  bool _loading = false;
  bool _navigatingToDashboard = false;
  String? _message;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tokenController.dispose();
    super.dispose();
  }

  void _refreshStatus() {
    if (!mounted) return;
    setState(() {
      _statusFuture = BackendApiService.getConnectionStatus();
    });
  }

  Future<void> _pollStatus() async {
    final previous = await _statusFuture?.catchError(
      (_) => const BackendConnectionStatus(connected: false, message: ''),
    );
    try {
      final current = await BackendApiService.getConnectionStatus();
      if (!mounted) return;
      setState(() { _statusFuture = Future.value(current); });
      if (current.approved && !_navigatingToDashboard) {
        _navigatingToDashboard = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delegasi berhasil diaktifkan.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppEntryScreen()),
          (_) => false,
        );
        return;
      }
      if (previous?.status == 'PENDING' && current.status == 'ACTIVE') {
        setState(
          () => _message = 'Permintaan disetujui. Delegasi Anda sudah aktif.',
        );
      } else if (previous?.status == 'PENDING' &&
          current.status == 'REJECTED') {
        setState(
          () => _message = 'Permintaan Delegasi ditolak oleh Orang Tua.',
        );
      }
    } catch (_) {
      // Keep the last visible status when the connection is temporarily unavailable.
    }
  }

  Future<void> _lookupInvitation() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() { _message = 'Masukkan kode undangan terlebih dahulu.'; });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final invitation = await BackendApiService.previewDelegationInvitation(
        token,
      );
      if (!mounted) return;
      setState(() { _invitation = invitation; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Token tidak valid atau undangan sudah tidak berlaku.';
      });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _acceptInvitation() async {
    final invitation = _invitation;
    if (invitation == null || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await BackendApiService.connectWithToken(invitation.token);
      if (!mounted) return;
      setState(() { _invitation = null; });
      _tokenController.clear();
      _refreshStatus();
      setState(() {
        _message =
            'Permintaan Anda telah dikirim kepada Orang Tua. Tunggu persetujuan sebelum menggunakan fitur Delegasi.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Token tidak dapat diproses. Pastikan undangan masih berlaku.';
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _declineInvitation() async {
    final invitation = _invitation;
    if (invitation == null || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await BackendApiService.declineDelegationInvitation(invitation.token);
      if (!mounted) return;
      setState(() {
        _invitation = null;
        _message = 'Undangan ditolak.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Undangan gagal ditolak. Silakan coba lagi.';
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar(
        'Hubungkan ke Orang Tua',
        pataraTeal,
        icon: Icons.link,
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await BackendApiService.clearSession(
                clearPassword: true,
                clearEmail: true,
              );
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const AppEntryScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26A69A), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roleLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masukkan token undangan dari Orang Tua untuk menghubungkan akun ini.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Setelah tersambung, status koneksi akan tampil di dashboard.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<BackendConnectionStatus>(
                future: _statusFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final status = snapshot.data?.status ?? 'NONE';
                  final connected = snapshot.data?.connected == true;
                  final statusText = switch (status) {
                    'PENDING' => 'Menunggu Validasi',
                    'REJECTED' => 'Permintaan ditolak',
                    'REVOKED' => 'Akses dicabut',
                    'ACTIVE' => 'Delegasi Aktif',
                    _ => 'Belum terhubung',
                  };
                  final statusColor = status == 'ACTIVE'
                      ? const Color(0xFF2E7D32)
                      : status == 'REJECTED'
                      ? const Color(0xFFC62828)
                      : const Color(0xFFF57C00);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        if (connected) ...[
                          const SizedBox(height: 8),
                          Text(
                            snapshot.data?.message ?? '',
                            style: const TextStyle(color: Color(0xFF5E5871)),
                          ),
                          if (snapshot.data?.childName != null)
                            Text(
                              'Anak: ${snapshot.data!.childName}',
                              style: const TextStyle(color: Color(0xFF5E5871)),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_invitation case final invitation?) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Undangan Delegasi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Anda diundang untuk membantu mencatat aktivitas anak pada TARA.',
                      ),
                      const SizedBox(height: 12),
                      Text('Orang Tua: ${invitation.parentName}'),
                      Text('Anak: ${invitation.childName}'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _loading ? null : _declineInvitation,
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _loading ? null : _acceptInvitation,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Terima Undangan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _tokenController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Kode undangan',
                    hintText: 'Contoh: PATARA-8F4K2',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _lookupInvitation,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'Memeriksa...' : 'Lanjut'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF06292),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.toLowerCase().contains('gagal')
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
