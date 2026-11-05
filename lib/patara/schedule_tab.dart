import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../services/local_notification_service.dart';
import 'parent_shell.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

class ScheduleTab extends StatelessWidget {
  final ChildrenController controller;

  const ScheduleTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final child = controller.selected;
        if (child == null) {
          return const EmptyView(
            icon: Icons.calendar_month,
            title: 'Belum ada anak',
            message: 'Tambahkan data anak di Beranda untuk membuat jadwal aktivitas.',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ChildSelector(controller: controller),
            ),
            Expanded(child: _ScheduleList(key: ValueKey(child.id), child: child)),
          ],
        );
      },
    );
  }
}

class _ScheduleList extends StatefulWidget {
  final BackendChild child;

  const _ScheduleList({super.key, required this.child});

  @override
  State<_ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<_ScheduleList> {
  late Future<List<Map<String, dynamic>>> _items;

  static const _repeatLabels = {'none': 'Sekali', 'daily': 'Setiap hari', 'weekly': 'Setiap minggu'};

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final items = await PataraApi.schedules(widget.child.id);
    _syncReminders(items);
    return items;
  }

  // Memasang ulang pengingat agar tetap aktif setelah login di perangkat lain atau instal ulang.
  Future<void> _syncReminders(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      final time = DateTime.tryParse('${item['reminder_time']}');
      if (time == null) continue;
      try {
        await LocalNotificationService.scheduleReminder(
          scheduleId: '${item['id']}',
          time: time,
          repeatRule: '${item['repeat_rule']}',
          title: 'Jadwal ${widget.child.nama}',
          body: '${item['title']}',
        );
      } catch (_) {
        // Perangkat tanpa dukungan notifikasi tetap dapat memakai daftar jadwal.
        return;
      }
    }
  }

  void _reload() => setState(() { _items = _load(); });

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _add() async {
    final options = await PataraApi.formOptions();
    if (!mounted) return;
    final draft = await showModalBottomSheet<_ScheduleDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleForm(options: options),
    );
    if (draft == null) return;
    try {
      final created = await PataraApi.createSchedule(
        childId: widget.child.id,
        title: draft.title,
        category: draft.category,
        reminderTime: draft.time,
        repeatRule: draft.repeat,
        description: draft.note,
      );
      var reminderSet = true;
      try {
        reminderSet = await LocalNotificationService.scheduleReminder(
          scheduleId: '${created['id']}',
          time: draft.time,
          repeatRule: draft.repeat,
          title: 'Jadwal ${widget.child.nama}',
          body: draft.title,
        );
      } catch (_) {
        reminderSet = false;
      }
      if (!mounted) return;
      showMessage(
        context,
        reminderSet
            ? 'Jadwal tersimpan dan pengingat dipasang. Pengasuh menerimanya sebagai tugas.'
            : 'Jadwal tersimpan dan dikirim ke pengasuh sebagai tugas, tetapi pengingat tidak dapat dipasang di perangkat ini.',
      );
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _toggle(Map<String, dynamic> item, bool done) async {
    try {
      await PataraApi.setScheduleDone('${item['id']}', DateTime.now(), done);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus jadwal ini?',
      message: 'Pengingat untuk "${item['title']}" juga dimatikan.',
    );
    if (!confirmed) return;
    try {
      await PataraApi.deleteSchedule('${item['id']}');
      await LocalNotificationService.cancelReminder('${item['id']}').catchError((_) {});
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AsyncView<List<Map<String, dynamic>>>(
          future: _items,
          onRetry: _reload,
          builder: (context, items) {
            if (items.isEmpty) {
              return EmptyView(
                icon: Icons.calendar_month,
                title: 'Belum ada jadwal',
                message:
                    'Buat jadwal makan, tidur, bermain, atau membaca untuk ${widget.child.nama} dan dapatkan pengingatnya.',
                actionLabel: 'Buat Jadwal',
                onAction: _add,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final time = DateTime.tryParse('${item['reminder_time']}')?.toLocal();
                final repeat = '${item['repeat_rule']}';
                final done = (item['done_dates'] as List).contains(_today);
                final doneBy = (item['done_by'] as Map?)?[_today] as Map?;
                final status = !done
                    ? 'Belum dilakukan'
                    : doneBy?['role'] == 'delegasi'
                    ? 'Dikerjakan ${doneBy?['name'] ?? 'Delegasi'}'
                    : 'Selesai hari ini';
                final when = time == null
                    ? ''
                    : repeat == 'none'
                    ? '${formatDate(time)} pukul ${formatTime(time)}'
                    : 'Pukul ${formatTime(time)}';
                return PataraCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(value: done, onChanged: (value) => _toggle(item, value ?? false)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                              Text(
                                'Catatan untuk pengasuh: ${item['description']}',
                                style: const TextStyle(fontSize: 12.5, color: pataraInk),
                              ),
                            Text(
                              '$when • ${_repeatLabels[repeat] ?? repeat} • $status',
                              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus jadwal',
                        onPressed: () => _delete(item),
                        icon: const Icon(Icons.delete_outline, color: Colors.black38),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-schedule-${widget.child.id}',
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Jadwal'),
          ),
        ),
      ],
    );
  }
}

class _ScheduleDraft {
  final String title;
  final String category;
  final DateTime time;
  final String repeat;
  final String note;

  const _ScheduleDraft(this.title, this.category, this.time, this.repeat, this.note);
}

class _ScheduleForm extends StatefulWidget {
  final FormOptions options;

  const _ScheduleForm({required this.options});

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  late String _category = widget.options.categories.first.key;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _repeat = 'daily';

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim().isEmpty
        ? widget.options.categoryLabel(_category)
        : _title.text.trim();
    final time = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    Navigator.of(context).pop(_ScheduleDraft(title, _category, time, _repeat, _note.text.trim()));
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
            const Text('Jadwal baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.task_alt, size: 16, color: pataraTeal),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Jadwal ini juga muncul sebagai tugas di HP pengasuh anak ini.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final item in widget.options.categories)
                  ChoiceChip(
                    label: Text(item.label),
                    selected: _category == item.key,
                    onSelected: (_) => setState(() { _category = item.key; }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Judul (opsional)',
                hintText: 'Contoh: Membaca buku sebelum tidur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk pengasuh (opsional)',
                hintText: 'Contoh: nasi tim + sayur bayam, habiskan setengah porsi dulu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Setiap hari')),
                ButtonSegment(value: 'weekly', label: Text('Mingguan')),
                ButtonSegment(value: 'none', label: Text('Sekali')),
              ],
              selected: {_repeat},
              onSelectionChanged: (value) => setState(() { _repeat = value.first; }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_repeat != 'daily')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() { _date = picked; });
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(formatDate(_date)),
                    ),
                  ),
                if (_repeat != 'daily') const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _time);
                      if (picked != null) setState(() { _time = picked; });
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text('Pukul ${two(_time.hour)}.${two(_time.minute)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 48, child: ElevatedButton(onPressed: _submit, child: const Text('Simpan Jadwal'))),
          ],
        ),
      ),
    );
  }
}
