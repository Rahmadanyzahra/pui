import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../services/local_notification_service.dart';

class MenuJadwalTab extends StatefulWidget {
  final int? childId;
  final Color? themeColor;

  const MenuJadwalTab({super.key, this.childId, this.themeColor});

  @override
  State<MenuJadwalTab> createState() => _MenuJadwalTabState();
}

class _MenuJadwalTabState extends State<MenuJadwalTab> {
  bool _autoReminderEnabled = true;
  int _learnReminderHour = 19;
  int _sleepReminderHour = 21;
  bool _saving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  late Future<List<_ScheduleItem>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _loadSchedules();
    _loadPreferences();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await BackendApiService.getEmailPreferences();
      if (!mounted) return;
      setState(() {
        _autoReminderEnabled = (prefs['weekly_recap'] as bool?) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    try {
      await BackendApiService.updateEmailPreferences(
        weeklyRecap: _autoReminderEnabled,
        alerts: true,
        notifyDeviations: true,
      );
      await LocalNotificationService.syncFamilyReminders(
        autoReminderEnabled: _autoReminderEnabled,
        learnReminderHour: _learnReminderHour,
        sleepReminderHour: _sleepReminderHour,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferensi jadwal tersimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal simpan preferensi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<_ScheduleItem>> _loadSchedules() async {
    final activities = await BackendApiService.getActivities(
      childId: widget.childId,
    );
    final schedules = <_ScheduleItem>[];
    for (final activity in activities) {
      if (activity.activityType != 'schedule') continue;
      try {
        final decoded = jsonDecode(activity.value);
        if (decoded is! Map<String, dynamic>) continue;
        schedules.add(
          _ScheduleItem(
            title: decoded['title']?.toString() ?? 'Routine',
            note: decoded['note']?.toString() ?? '',
            scheduleDate:
                DateTime.tryParse(decoded['scheduleDate']?.toString() ?? '') ??
                DateTime.tryParse(activity.createdAt) ??
                DateTime.now(),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    schedules.sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
    return schedules.reversed.take(12).toList(growable: false);
  }

  Future<void> _addSchedule() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final payload = {
        'title': title,
        'note': _noteController.text.trim(),
        'scheduleDate': DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _learnReminderHour,
        ).toIso8601String(),
      };

      if (widget.childId != null) {
        await BackendApiService.logActivity(
          childId: widget.childId!,
          activityType: 'schedule',
          value: jsonEncode(payload),
        );
      } else {
        await BackendApiService.logParentActivity(
          activityType: 'schedule',
          value: jsonEncode(payload),
        );
      }

      _titleController.clear();
      _noteController.clear();
      _scheduleFuture = _loadSchedules();

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal berhasil ditambahkan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal tambah jadwal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;
    setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.themeColor ?? const Color(0xFF8B5FBF);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jadwal & Reminder',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _autoReminderEnabled,
            onChanged: (v) => setState(() => _autoReminderEnabled = v),
            title: const Text('Aktifkan auto reminder'),
          ),
          ListTile(
            title: const Text('Jam reminder belajar'),
            subtitle: Text(
              '${_learnReminderHour.toString().padLeft(2, '0')}:00',
            ),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: _learnReminderHour.toDouble(),
                min: 6,
                max: 22,
                divisions: 16,
                onChanged: (v) =>
                    setState(() => _learnReminderHour = v.round()),
              ),
            ),
          ),
          ListTile(
            title: const Text('Jam reminder tidur'),
            subtitle: Text(
              '${_sleepReminderHour.toString().padLeft(2, '0')}:00',
            ),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: _sleepReminderHour.toDouble(),
                min: 18,
                max: 23,
                divisions: 5,
                onChanged: (v) =>
                    setState(() => _sleepReminderHour = v.round()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saving ? null : _savePreferences,
            child: const Text('Simpan Preferensi'),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Jadwal',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: _pickDate,
                      child: Text(
                        'Tanggal: ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _saving ? null : _addSchedule,
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Routine Terakhir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<_ScheduleItem>>(
            future: _scheduleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <_ScheduleItem>[];
              if (items.isEmpty) {
                return const ListTile(
                  title: Text('Belum ada jadwal'),
                  subtitle: Text('Tambahkan jadwal pertama Anda.'),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(item.title),
                        subtitle: Text(
                          item.note.isEmpty
                              ? item.scheduleDate.toString()
                              : '${item.note}\n${item.scheduleDate}',
                        ),
                        isThreeLine: item.note.isNotEmpty,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem {
  final String title;
  final String note;
  final DateTime scheduleDate;

  const _ScheduleItem({
    required this.title,
    required this.note,
    required this.scheduleDate,
  });
}
