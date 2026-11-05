import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';
import '../services/input_validation_service.dart';

class FamilyDelegationParentProfileEditScreen extends StatefulWidget {
  const FamilyDelegationParentProfileEditScreen({super.key});

  @override
  State<FamilyDelegationParentProfileEditScreen> createState() =>
      _FamilyDelegationParentProfileEditScreenState();
}

class _FamilyDelegationParentProfileEditScreenState
    extends State<FamilyDelegationParentProfileEditScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _photoPath;
  Uint8List? _serverPhotoBytes;
  bool _loading = false;
  bool _initializing = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await BackendApiService.getProfile();
      if (!mounted) return;
      _fullNameController.text = profile['full_name']?.toString() ?? '';
      _emailController.text = profile['email']?.toString() ?? '';
      _phoneController.text = profile['phone']?.toString() ?? '';
      if (profile['photo_path'] != null) {
        _serverPhotoBytes = Uint8List.fromList(
          await BackendApiService.getProfilePhotoBytes(),
        );
      }
    } catch (error) {
      _message = 'Gagal memuat profil. Periksa koneksi lalu coba lagi.';
    } finally {
      if (mounted) setState(() { _initializing = false; });
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      setState(() { _message = 'Nama lengkap dan email wajib diisi.'; });
      return;
    }

    if (!InputValidationService.isValidName(fullName)) {
      setState(
        () =>
            _message = 'Nama harus berisi huruf, bukan angka atau simbol saja.',
      );
      return;
    }

    if (phone.isNotEmpty && !InputValidationService.isValidPhone(phone)) {
      setState(() { _message = 'Nomor telepon tidak valid.'; });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await BackendApiService.saveProfile(
        fullName: fullName,
        phone: phone,
        photoPath: _photoPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil disimpan.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = 'Profil gagal disimpan. Periksa data lalu coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _choosePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() { _photoPath = picked.path; });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil gagal dipilih. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Profil Saya', pataraPurple, icon: Icons.person_outline),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _initializing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perbarui profil Orang Tua yang terhubung dengan Delegasi.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: const Color(0xFFF8F7F4),
                            foregroundImage: _photoPath != null
                                // Di browser foto pilihan berupa alamat sementara, bukan berkas di perangkat.
                                ? (kIsWeb ? NetworkImage(_photoPath!) : FileImage(File(_photoPath!)) as ImageProvider)
                                : _serverPhotoBytes != null
                                ? MemoryImage(_serverPhotoBytes!)
                                : null,
                            child: _photoPath == null
                                ? const Icon(
                                    Icons.person,
                                    size: 42,
                                    color: Color(0xFF9E9E9E),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _choosePhoto,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Ubah Foto Profil'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveProfile,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Simpan Profil'),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
