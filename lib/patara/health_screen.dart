import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Kesehatan anak: daftar imunisasi dan catatan kesehatan (sakit, kunjungan, alergi).
class HealthScreen extends StatefulWidget {
  final BackendChild child;

  const HealthScreen({super.key, required this.child});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late Future<Map<String, dynamic>> _data;

  static const _typeIcons = {
    'imunisasi': Icons.vaccines,
    'sakit': Icons.sick_outlined,
    'kunjungan': Icons.local_hospital_outlined,
    'alergi': Icons.warning_amber,
    'lainnya': Icons.note_alt_outlined,
  };

  @override
  void initState() {
    super.initState();
    _data = PataraApi.health(widget.child.id);
  }

  void _reload() => setState(() { _data = PataraApi.health(widget.child.id); });

  Future<DateTime?> _pickDate(String help, {DateTime? initial}) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: widget.child.birthDate ?? DateTime(DateTime.now().year - 6),
    lastDate: DateTime.now(),
    helpText: help,
  );

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

  Future<void> _toggleVaccine(Map<String, dynamic> vaccine) async {
    if (vaccine['given_date'] != null) {
      final remove = await confirmDialog(
        context,
        title: 'Batalkan catatan ${vaccine['label']}?',
        message: 'Imunisasi ini akan ditandai belum dicatat.',
        confirmLabel: 'Batalkan catatan',
      );
      if (remove) {
        await _run(() => PataraApi.deleteHealth(widget.child.id, vaccine['record_id'] as Object), 'Catatan imunisasi dibatalkan.');
      }
      return;
    }
    final date = await _pickDate('Tanggal ${vaccine['label']} diberikan');
    if (date == null) return;
    await _run(
      () => PataraApi.addHealth(widget.child.id, recordType: 'imunisasi', vaccineKey: '${vaccine['key']}', date: date),
      '${vaccine['label']} dicatat.',
    );
  }

  Future<void> _addRecord(List<Map<String, dynamic>> types) async {
    final draft = await showModalBottomSheet<(String, String, DateTime, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HealthForm(
        types: types.where((type) => type['key'] != 'imunisasi').toList(),
        firstDate: widget.child.birthDate ?? DateTime(DateTime.now().year - 6),
      ),
    );
    if (draft == null) return;
    await _run(
      () => PataraApi.addHealth(widget.child.id, recordType: draft.$1, title: draft.$2, date: draft.$3, notes: draft.$4),
      'Catatan kesehatan tersimpan.',
    );
  }

  String _ageHint(int months) => months == 0
      ? 'Saat lahir'
      : months < 12
      ? 'Usia $months bulan'
      : 'Usia ${months ~/ 12} tahun${months % 12 == 0 ? '' : ' ${months % 12} bulan'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Kesehatan ${widget.child.nama}', pataraOrange, icon: Icons.vaccines_outlined),
      body: AsyncView<Map<String, dynamic>>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) {
          final vaccines = (data['immunizations'] as List).cast<Map<String, dynamic>>();
          final types = (data['types'] as List).cast<Map<String, dynamic>>();
          final records = (data['records'] as List)
              .cast<Map<String, dynamic>>()
              .where((record) => record['record_type'] != 'imunisasi')
              .toList();
          final given = data['immunizations_given'] as int;
          final total = data['immunizations_total'] as int;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              PataraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vaccines, color: pataraTeal),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Imunisasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                        Text('$given dari $total', style: const TextStyle(color: pataraTeal, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : given / total,
                        minHeight: 10,
                        color: pataraTeal,
                        backgroundColor: pataraTeal.withOpacity(0.15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ketuk imunisasi yang sudah diberikan untuk mencatat tanggalnya.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PataraCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final vaccine in vaccines)
                      ListTile(
                        dense: true,
                        onTap: () => _toggleVaccine(vaccine),
                        leading: Icon(
                          vaccine['given_date'] != null ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: vaccine['given_date'] != null ? pataraTeal : Colors.black26,
                        ),
                        title: Text('${vaccine['label']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          vaccine['given_date'] != null
                              ? 'Diberikan ${formatDate(DateTime.parse('${vaccine['given_date']}'))}'
                              : _ageHint(vaccine['age_months'] as int),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              SectionTitle(
                'Catatan kesehatan',
                trailing: TextButton.icon(
                  onPressed: () => _addRecord(types),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                ),
              ),
              if (records.isEmpty)
                const PataraCard(
                  child: Text(
                    'Belum ada catatan. Catat saat anak sakit, berkunjung ke dokter atau posyandu, atau punya alergi.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                )
              else
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PataraCard(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: pataraOrange.withOpacity(0.14),
                            child: Icon(_typeIcons['${record['record_type']}'] ?? Icons.note_alt_outlined, color: pataraOrange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${record['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  formatDate(DateTime.parse('${record['record_date']}')),
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                if ('${record['notes']}'.isNotEmpty) Text('${record['notes']}', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus catatan kesehatan',
                            onPressed: () async {
                              final confirmed = await confirmDialog(
                                context,
                                title: 'Hapus catatan ini?',
                                message: 'Catatan "${record['title']}" akan dihapus.',
                              );
                              if (confirmed) {
                                await _run(() => PataraApi.deleteHealth(widget.child.id, record['id'] as Object), 'Catatan dihapus.');
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.black38),
                          ),
                        ],
                      ),
                    ),
                  ),
              const DisclaimerNote(
                'Daftar imunisasi adalah acuan umum program imunisasi nasional. Jadwal dan jenis imunisasi anak Anda mengikuti arahan posyandu, puskesmas, atau dokter anak.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HealthForm extends StatefulWidget {
  final List<Map<String, dynamic>> types;
  final DateTime firstDate;

  const _HealthForm({required this.types, required this.firstDate});

  @override
  State<_HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<_HealthForm> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  late String _type = '${widget.types.first['key']}';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
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
            const Text('Catatan kesehatan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in widget.types)
                  ChoiceChip(
                    label: Text('${type['label']}'),
                    selected: _type == type['key'],
                    onSelected: (_) => setState(() { _type = '${type['key']}'; }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Judul',
                hintText: 'Contoh: Batuk pilek, kontrol ke posyandu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Keterangan (opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: widget.firstDate,
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() { _date = picked; });
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(formatDate(_date)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_title.text.trim().isEmpty) {
                    showMessage(context, 'Isi judul catatan.');
                    return;
                  }
                  Navigator.of(context).pop((_type, _title.text.trim(), _date, _notes.text.trim()));
                },
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
