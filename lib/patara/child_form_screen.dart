import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../utils/child_age.dart';
import 'patara_ui.dart';

/// Formulir tambah atau ubah data anak. Mengembalikan true bila tersimpan.
class ChildFormScreen extends StatefulWidget {
  final BackendChild? child;

  const ChildFormScreen({super.key, this.child});

  @override
  State<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends State<ChildFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  DateTime? _birthDate;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.child?.nama ?? '');
    _birthDate = widget.child?.birthDate;
    final gender = widget.child?.gender?.toUpperCase();
    _gender = gender == 'L' || gender == 'P' ? gender : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ChildAge? get _age => _birthDate == null ? null : ChildAge.calculate(_birthDate!);

  String get _categoryLabel => switch (_age?.category) {
    'baby' => 'Bayi (0–<1 tahun)',
    'toddler' => 'Toddler (1–<2 tahun)',
    'balita' => 'Balita (2–5 tahun)',
    _ => 'Di luar rentang 0–5 tahun',
  };

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? today,
      firstDate: DateTime(today.year - 6, today.month, today.day),
      lastDate: today,
      helpText: 'Tanggal lahir anak',
    );
    if (picked != null) setState(() { _birthDate = picked; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null || _gender == null) {
      showMessage(context, 'Lengkapi tanggal lahir dan jenis kelamin.');
      return;
    }
    if (_age == null || _age!.category == 'di_luar_rentang') {
      showMessage(context, 'PATARA hanya mendukung anak usia 0 sampai 5 tahun.');
      return;
    }
    setState(() { _saving = true; });
    try {
      await BackendApiService.saveChild(
        childId: widget.child?.id,
        nama: _name.text.trim(),
        birthDate: _birthDate!,
        gender: _gender!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar(
        widget.child == null ? 'Tambah Anak' : 'Ubah Data Anak',
        pataraBlue,
        icon: Icons.child_care,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama anak',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Nama minimal 2 huruf'
                  : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal lahir',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _birthDate == null ? 'Pilih tanggal' : formatDate(_birthDate!),
                ),
              ),
            ),
            if (_age != null) ...[
              const SizedBox(height: 8),
              Text(
                'Usia: ${_age!.formatted} • $_categoryLabel',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Jenis kelamin'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: 'L', label: Text('Laki-laki')),
                ButtonSegment(value: 'P', label: Text('Perempuan')),
              ],
              selected: {?_gender},
              onSelectionChanged: (value) =>
                  setState(() { _gender = value.isEmpty ? null : value.first; }),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
