import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Formulir pencatatan aktivitas untuk Orang Tua dan Delegasi.
/// Mengembalikan true bila aktivitas tersimpan.
class ActivityFormScreen extends StatefulWidget {
  final BackendChild child;
  final bool isDelegate;

  /// Isian awal, misalnya draf yang ditangkap AI Chat dari cerita orang tua.
  final Map<String, dynamic>? initial;

  const ActivityFormScreen({
    super.key,
    required this.child,
    this.isDelegate = false,
    this.initial,
  });

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  late Future<FormOptions> _options;
  final _description = TextEditingController();
  String? _category;
  DateTime _at = DateTime.now();
  String? _moodBefore;
  String? _moodAfter;
  int? _fussy;
  int _tantrum = 0;
  String _status = 'selesai';
  String? _photoPath;
  bool _saving = false;
  String? _mealPortion;
  final _foodGroups = <String>{};

  /// Durasi yang diketik pelapor; hanya klaim dan ditandai "manual".
  int? _durationMinutes;

  /// Timer Delegasi yang sedang berjalan; durasinya dihitung server saat disimpan.
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _options = PataraApi.formOptions(refresh: true);
    if (widget.isDelegate) _loadSession();
    final initial = widget.initial;
    if (initial != null) {
      _category = initial['category'] as String?;
      _description.text = (initial['description'] ?? '').toString();
      _at = DateTime.tryParse('${initial['event_at']}')?.toLocal() ?? _at;
      _moodBefore = initial['mood_before'] as String?;
      _moodAfter = initial['mood_after'] as String?;
      _fussy = (initial['fussy_level'] as num?)?.toInt();
      _tantrum = (initial['tantrum_count'] as num?)?.toInt() ?? 0;
      _status = (initial['status'] ?? 'selesai').toString();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final session = await PataraApi.activeSession();
      if (session == null || !mounted) return;
      setState(() {
        _session = session;
        _category = session['category'] as String?;
      });
    } catch (_) {
      // Tanpa timer, formulir tetap dapat dipakai dengan durasi manual.
    }
  }

  Future<void> _startTimer() async {
    if (_category == null) {
      showMessage(context, 'Pilih jenis aktivitas terlebih dahulu.');
      return;
    }
    setState(() { _saving = true; });
    try {
      final session = await PataraApi.startSession(_category!);
      if (!mounted) return;
      final started = DateTime.parse('${session['started_at']}').toLocal();
      showMessage(
        context,
        'Timer dimulai pukul ${formatTime(started)} dan Orang Tua diberi tahu. Buka lagi "Catat" saat aktivitas selesai.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Future<void> _cancelTimer() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Batalkan timer?',
      message: 'Jam mulai yang sudah dicatat server akan dihapus dan tidak dapat dikembalikan.',
    );
    if (!confirmed) return;
    try {
      await PataraApi.cancelSession('${_session!['id']}');
      if (mounted) setState(() { _session = null; });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _pickDuration() async {
    final hours = TextEditingController(text: _durationMinutes == null ? '' : '${_durationMinutes! ~/ 60}');
    final minutes = TextEditingController(text: _durationMinutes == null ? '' : '${_durationMinutes! % 60}');
    InputDecoration decoration(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Durasi aktivitas'),
        content: Row(
          children: [
            Expanded(
              child: TextField(controller: hours, keyboardType: TextInputType.number, decoration: decoration('Jam')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(controller: minutes, keyboardType: TextInputType.number, decoration: decoration('Menit')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(0), child: const Text('Hapus')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              (int.tryParse(hours.text.trim()) ?? 0) * 60 + (int.tryParse(minutes.text.trim()) ?? 0),
            ),
            child: const Text('Pakai'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    if (result < 0 || result > 1440) {
      showMessage(context, 'Durasi paling lama 24 jam.');
      return;
    }
    setState(() { _durationMinutes = result == 0 ? null : result; });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() { _at = picked.isAfter(now) ? now : picked; });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null && mounted) setState(() { _photoPath = file.path; });
    } catch (_) {
      if (mounted) showMessage(context, 'Foto tidak dapat diambil di perangkat ini.');
    }
  }

  Future<void> _save(FormOptions options) async {
    final category = options.categories
        .where((item) => item.key == _category)
        .firstOrNull;
    if (category == null) {
      showMessage(context, 'Pilih jenis aktivitas terlebih dahulu.');
      return;
    }
    if (widget.isDelegate && category.requiresPhoto && _photoPath == null) {
      showMessage(context, 'Aktivitas ${category.label} wajib menyertakan foto bukti.');
      return;
    }
    setState(() { _saving = true; });
    try {
      final photoSaved = await PataraApi.saveActivity(
        childId: widget.child.id,
        category: category.key,
        photoPath: _photoPath,
        data: {
          'description': _description.text.trim(),
          'event_at': _at.toUtc().toIso8601String(),
          'mood_before': _moodBefore,
          'mood_after': _moodAfter,
          'fussy_level': _fussy,
          'tantrum_count': _tantrum,
          'status': _status,
          if (_session != null)
            'session_id': _session!['id']
          else if (_durationMinutes != null)
            'duration_minutes': _durationMinutes,
          if (category.key == 'makan' && (_mealPortion != null || _foodGroups.isNotEmpty))
            'meal': {'portion': _mealPortion, 'food_groups': _foodGroups.toList()},
        },
      );
      if (!mounted) return;
      showMessage(
        context,
        photoSaved
            ? 'Aktivitas tersimpan.'
            : 'Aktivitas tersimpan, tetapi foto gagal diunggah.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  FormOptions? _loaded;

  @override
  Widget build(BuildContext context) {
    final category = _loaded?.categories.where((item) => item.key == _category).firstOrNull;
    final accent = category == null ? pataraPink : _categoryColor(category.key);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6FA),
      appBar: sectionAppBar('Catat Aktivitas ${widget.child.nama}', pataraPink, icon: Icons.edit_note),
      body: AsyncView<FormOptions>(
        future: _options,
        onRetry: () => setState(() { _options = PataraApi.formOptions(refresh: true); }),
        builder: (context, options) {
          if (_loaded == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() { _loaded = options; });
            });
          }
          return _buildForm(options);
        },
      ),
      // Tombol simpan selalu terlihat, tidak perlu menggulir sampai bawah.
      bottomNavigationBar: _loaded == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(_loaded!),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving ? 'Menyimpan...' : 'Simpan Aktivitas',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  static const _categoryColors = {
    'makan': Color(0xFFF06292),
    'tidur': Color(0xFF7E57C2),
    'bermain': Color(0xFFFB8C00),
    'belajar': Color(0xFF42A5F5),
    'mandi': Color(0xFF26A69A),
    'bersama_orang_tua': Color(0xFFD81B60),
    'menyusu': Color(0xFFEC407A),
    'popok': Color(0xFF26A69A),
    'tengkurap': Color(0xFFFFA000),
  };

  Color _categoryColor(String key) => _categoryColors[key] ?? const Color(0xFF78909C);

  static const _foodEmoji = {
    'pokok': '🍚',
    'hewani': '🍗',
    'nabati': '🥜',
    'sayur': '🥦',
    'buah': '🍎',
    'susu': '🥛',
  };

  /// Kartu berjudul yang mengelompokkan satu bagian formulir.
  Widget _section({required IconData icon, required String title, String? subtitle, Color color = pataraPink, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: pataraPink.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _subLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: pataraInk)),
  );

  /// Pilihan berbentuk kapsul; dipakai untuk porsi, kelompok pangan, dan tingkat rewel.
  Widget _pill(String label, bool selected, Color color, VoidCallback onTap, {String? emoji}) {
    return Material(
      color: selected ? color.withOpacity(0.14) : const Color(0xFFF7F2F6),
      shape: StadiumBorder(side: BorderSide(color: selected ? color : Colors.transparent, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[Text(emoji, style: const TextStyle(fontSize: 15)), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(fontSize: 13.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : pataraInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryGrid(FormOptions options) {
    // Kategori khusus kelompok usia (mis. menyusu untuk bayi) hanya muncul untuk usia itu.
    final items = options.categories.where((item) => item.ageGroup == null || item.ageGroup == widget.child.category).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _CategoryTile(
                  icon: item.icon,
                  label: item.label,
                  color: _categoryColor(item.key),
                  selected: _category == item.key,
                  // Selama timer berjalan, jenis aktivitas mengikuti timer.
                  onTap: _session == null ? () => setState(() { _category = item.key; }) : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _moodPicker(FormOptions options, String? value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        for (final mood in options.moods)
          Expanded(
            child: _MoodChoice(
              emoji: moodEmoji[mood.key] ?? '',
              label: mood.label,
              selected: value == mood.key,
              onTap: () => onChanged(value == mood.key ? null : mood.key),
            ),
          ),
      ],
    );
  }

  Widget _buildTime() {
    final session = _session;
    if (session != null) {
      final started = DateTime.parse('${session['started_at']}').toLocal();
      final elapsed = DateTime.now().difference(started).inMinutes;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: pataraPurple.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: pataraPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Timer berjalan sejak ${formatTime(started)} (${formatDuration(elapsed < 0 ? 0 : elapsed)}). '
                    'Durasi dihitung server saat laporan ini disimpan.',
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _cancelTimer, child: const Text('Batalkan timer')),
        ],
      );
    }
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: pataraInk,
      side: const BorderSide(color: Color(0xFFE9DDE5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tanggal dan waktu', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickDateTime,
            style: buttonStyle,
            icon: const Icon(Icons.event, color: pataraPink),
            label: Align(alignment: Alignment.centerLeft, child: Text('${formatDate(_at)} pukul ${formatTime(_at)}')),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.isDelegate)
              FilledButton.tonalIcon(
                onPressed: _saving ? null : _startTimer,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Mulai timer sekarang'),
              ),
            OutlinedButton.icon(
              onPressed: _pickDuration,
              style: buttonStyle,
              icon: const Icon(Icons.timelapse, color: pataraPurple),
              label: Text(_durationMinutes == null ? 'Isi durasi manual' : '${formatDuration(_durationMinutes!)} (manual)'),
            ),
          ],
        ),
        if (widget.isDelegate)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Timer mencatat jam mulai dan selesai memakai jam server, sehingga durasinya terverifikasi. '
              'Durasi manual tetap tersimpan tetapi ditandai tidak terverifikasi.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoto(bool required) {
    final path = _photoPath;
    if (path != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: kIsWeb ? Image.network(path, fit: BoxFit.cover) : Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Foto terpilih', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Ikut terkirim saat disimpan.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus foto',
            onPressed: () => setState(() { _photoPath = null; }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    final color = required ? pataraPink : pataraInk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: required ? pataraPink.withOpacity(0.05) : const Color(0xFFF9F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: required ? pataraPink.withOpacity(0.5) : const Color(0xFFE9DDE5), width: 1.4),
      ),
      child: Column(
        children: [
          Icon(Icons.add_a_photo_outlined, size: 30, color: color.withOpacity(0.8)),
          const SizedBox(height: 6),
          Text(
            required ? 'Kategori ini wajib disertai foto.' : 'Tambahkan foto bila ada.',
            style: TextStyle(fontSize: 13, color: color, fontWeight: required ? FontWeight.w600 : FontWeight.w400),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(FormOptions options) {
    final category = options.categories
        .where((item) => item.key == _category)
        .firstOrNull;
    final photoRequired = widget.isDelegate && (category?.requiresPhoto ?? false);
    final accent = category == null ? pataraPink : _categoryColor(category.key);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: [
        _section(
          icon: Icons.category_outlined,
          title: 'Jenis aktivitas',
          subtitle: category == null ? 'Pilih satu kegiatan yang dicatat.' : null,
          child: _categoryGrid(options),
        ),
        _section(
          icon: Icons.schedule,
          title: 'Waktu dan durasi',
          color: pataraPurple,
          child: _buildTime(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: category?.key == 'makan' && options.foodGroups.isNotEmpty
              ? _section(
                  icon: Icons.restaurant,
                  title: 'Detail makan',
                  color: _categoryColor('makan'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Porsi yang dihabiskan', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final portion in options.mealPortions)
                            _pill(portion.label, _mealPortion == portion.key, accent,
                                () => setState(() { _mealPortion = _mealPortion == portion.key ? null : portion.key; })),
                        ],
                      ),
                      _subLabel('Isi piring (kelompok pangan)'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final group in options.foodGroups)
                            _pill(group.label, _foodGroups.contains(group.key), accent, emoji: _foodEmoji[group.key], () => setState(() {
                              if (!_foodGroups.remove(group.key)) _foodGroups.add(group.key);
                            })),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        _section(
          icon: Icons.notes,
          title: 'Ceritakan singkat',
          subtitle: 'Apa yang terjadi? Keterangan membantu membaca pola.',
          color: pataraBlue,
          child: TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Contoh: makan siang nasi dan sayur, habis setengah porsi',
              filled: true,
              fillColor: const Color(0xFFF9F6F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: pataraPink, width: 1.4)),
            ),
          ),
        ),
        _section(
          icon: Icons.mood,
          title: 'Perasaan anak',
          color: pataraOrange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mood sebelum aktivitas', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              const SizedBox(height: 8),
              _moodPicker(options, _moodBefore, (value) => setState(() { _moodBefore = value; })),
              const SizedBox(height: 14),
              const Text('Mood setelah aktivitas', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              const SizedBox(height: 8),
              _moodPicker(options, _moodAfter, (value) => setState(() { _moodAfter = value; })),
            ],
          ),
        ),
        _section(
          icon: Icons.psychology_alt_outlined,
          title: 'Perilaku',
          color: pataraTeal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tingkat rewel', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var level = 0; level < options.fussyLevels.length; level++)
                    _pill(options.fussyLevels[level], _fussy == level, pataraTeal,
                        () => setState(() { _fussy = _fussy == level ? null : level; })),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jumlah tantrum', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text('Mengamuk, menjerit, atau berguling', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _tantrum > 0 ? () => setState(() { _tantrum--; }) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$_tantrum',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _tantrum < 50 ? () => setState(() { _tantrum++; }) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'selesai', label: Text('Selesai'), icon: Icon(Icons.check)),
                    ButtonSegment(value: 'tidak_selesai', label: Text('Tidak selesai'), icon: Icon(Icons.close)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (value) => setState(() { _status = value.first; }),
                ),
              ),
            ],
          ),
        ),
        _section(
          icon: Icons.photo_camera_outlined,
          title: photoRequired ? 'Foto bukti (wajib)' : 'Foto bukti (opsional)',
          subtitle: 'Dihapus otomatis setelah 30 hari; catatannya tetap tersimpan.',
          color: photoRequired ? pataraPink : pataraInk,
          child: _buildPhoto(photoRequired),
        ),
      ],
    );
  }
}

/// Kotak pilihan jenis aktivitas: ikon dalam lingkaran berwarna dan nama di bawahnya.
class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryTile({required this.icon, required this.label, required this.color, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 96,
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.12) : const Color(0xFFF9F6F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? color : Colors.transparent, width: 1.8),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.1 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: selected ? color : color.withOpacity(0.14), shape: BoxShape.circle),
                          child: Icon(icon, size: 21, color: selected ? Colors.white : color),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? color : pataraInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(right: 7, top: 7, child: Icon(Icons.check_circle, size: 17, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan mood: emoji besar dalam lingkaran dan namanya di bawah.
class _MoodChoice extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MoodChoice({required this.emoji, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? pataraOrange.withOpacity(0.16) : const Color(0xFFF7F2F6),
                border: Border.all(color: selected ? pataraOrange : Colors.transparent, width: 2),
              ),
              child: AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 200),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? const Color(0xFFE65100) : pataraInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
