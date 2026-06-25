import 'package:flutter/material.dart';

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
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _refreshStatus() {
    setState(() {
      _statusFuture = BackendApiService.getConnectionStatus();
    });
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _message = 'Masukkan token dari parent terlebih dulu.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await BackendApiService.connectWithToken(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil terhubung ke parent.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      appBar: AppBar(
        title: const Text('Join ke Parent'),
        backgroundColor: const Color(0xFFF06292),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
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
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masukkan token yang diberikan parent untuk menghubungkan akun ini.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2538),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Setelah tersambung, status koneksi akan tampil di dashboard.',
                      style: TextStyle(color: Color(0xFF5E5871)),
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

                  final connected = snapshot.data?.connected == true;
                  final statusText = connected
                      ? 'Sudah terhubung ke parent'
                      : 'Belum terhubung';
                  final statusColor = connected
                      ? const Color(0xFF2E7D32)
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
                            'Token: ${snapshot.data?.token ?? '-'}',
                            style: const TextStyle(color: Color(0xFF5E5871)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tokenController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Token Parent',
                  hintText: 'Contoh: 6749BD10ECA14B4F',
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
                  onPressed: _loading ? null : _connect,
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
                      : const Icon(Icons.link),
                  label: Text(
                    _loading ? 'Menyambungkan...' : 'Gabung ke Parent',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF06292),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
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
