import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'parent_shell.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

class ActivityTab extends StatelessWidget {
  final ChildrenController controller;

  const ActivityTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final child = controller.selected;
        if (child == null) {
          return const EmptyView(
            icon: Icons.edit_note,
            title: 'Belum ada anak',
            message: 'Tambahkan data anak di Beranda untuk mulai mencatat aktivitas.',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ChildSelector(controller: controller),
            ),
            Expanded(
              child: ActivityHistory(key: ValueKey(child.id), child: child),
            ),
          ],
        );
      },
    );
  }
}

/// Status validasi Orang Tua atas catatan yang dibuat Delegasi.
class _ValidationChip extends StatelessWidget {
  final String status;
  final String note;

  const _ValidationChip({required this.status, required this.note});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'pending' => ('Menunggu validasi Orang Tua', pataraOrange, Icons.hourglass_top),
      'rejected' => (note.isEmpty ? 'Tidak sesuai' : 'Tidak sesuai: $note', const Color(0xFFC62828), Icons.close),
      _ => ('Tervalidasi', const Color(0xFF2E7D32), Icons.verified),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Riwayat aktivitas satu anak dengan tombol catat. Dipakai Orang Tua dan Delegasi.
class ActivityHistory extends StatefulWidget {
  final BackendChild child;
  final bool isDelegate;

  const ActivityHistory({super.key, required this.child, this.isDelegate = false});

  @override
  State<ActivityHistory> createState() => _ActivityHistoryState();
}

class _ActivityHistoryState extends State<ActivityHistory> {
  late Future<(FormOptions, List<ActivityLog>)> _data;

  /// Timer aktivitas Delegasi yang sedang berjalan.
  Map<String, dynamic>? _session;

  // Daftar dimuat ulang berkala, supaya catatan dari Orang Tua atau Delegasi di HP lain muncul
  // tanpa harus menarik layar ke bawah.
  Timer? _autoRefresh;

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refreshQuietly() async {
    try {
      final fresh = await _load();
      // Diganti setelah data baru siap, jadi daftar tidak berkedip menjadi tanda memuat.
      if (mounted) setState(() { _data = Future.value(fresh); });
    } catch (_) {
      // Sambungan terputus sesaat: daftar lama tetap ditampilkan.
    }
  }

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _refreshQuietly());
    _data = _load();
  }

  Future<(FormOptions, List<ActivityLog>)> _load() async {
    final options = await PataraApi.formOptions();
    if (widget.isDelegate) {
      // Riwayat tetap tampil walau status timer gagal dimuat.
      final session = await PataraApi.activeSession().catchError((_) => null);
      if (mounted) setState(() { _session = session; });
    }
    return (options, await PataraApi.activityLogs(widget.child.id));
  }

  void _reload() => setState(() { _data = _load(); });

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityFormScreen(
          child: widget.child,
          isDelegate: widget.isDelegate,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(ActivityLog log) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus catatan ini?',
      message: 'Catatan aktivitas yang dihapus tidak ikut dihitung dalam laporan.',
    );
    if (!confirmed) return;
    try {
      await PataraApi.deleteActivity(log.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  void _showPhoto(ActivityLog log) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: FutureBuilder<Uint8List>(
          future: PataraApi.photoBytes(log.photoPath!),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Foto sudah tidak tersedia.'),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Image.memory(snapshot.data!, fit: BoxFit.contain)),
                if (log.photoExpiredAt != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Foto bukti ini dihapus otomatis pada ${formatDate(log.photoExpiredAt!.toLocal())}.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return _buildHistory();
    final started = DateTime.parse('${session['started_at']}').toLocal();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: PataraCard(
            padding: const EdgeInsets.all(12),
            onTap: _add,
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: pataraPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Timer aktivitas berjalan sejak ${formatTime(started)}. Ketuk untuk menyelesaikan dan mengirim laporan.',
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
                const Icon(Icons.chevron_right, color: pataraPurple),
              ],
            ),
          ),
        ),
        Expanded(child: _buildHistory()),
      ],
    );
  }

  Widget _buildHistory() {
    return Stack(
      children: [
        AsyncView<(FormOptions, List<ActivityLog>)>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) {
            final (options, logs) = data;
            if (logs.isEmpty) {
              return EmptyView(
                icon: Icons.edit_note,
                title: 'Belum ada catatan',
                message:
                    'Catat aktivitas ${widget.child.nama} seperti makan, tidur, dan bermain.',
                actionLabel: 'Catat Aktivitas',
                onAction: _add,
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final newDay =
                      index == 0 || !DateUtils.isSameDay(logs[index - 1].at, log.at);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (newDay)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            formatDate(log.at),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      _buildItem(options, log),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-activity-${widget.child.id}',
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Catat'),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(FormOptions options, ActivityLog log) {
    final details = <String>[
      if (log.moodBefore != null || log.moodAfter != null)
        'Mood: ${moodEmoji[log.moodBefore] ?? '–'} → ${moodEmoji[log.moodAfter] ?? '–'}',
      if (log.fussyLevel != null && log.fussyLevel! < options.fussyLevels.length)
        options.fussyLevels[log.fussyLevel!],
      if (log.tantrumCount > 0) 'Tantrum ${log.tantrumCount}×',
      if (log.status == 'tidak_selesai') 'Tidak selesai',
      if (log.durationMinutes != null)
        durationEvidence(log.durationMinutes, log.durationSource, startedAt: log.startedAt, endedAt: log.endedAt),
      if (options.mealLabel(log.meal).isNotEmpty) options.mealLabel(log.meal),
    ];
    final performer = log.performerName.isEmpty
        ? ''
        : ' • ${log.performerName}${log.performerRole == 'delegasi' ? ' (Delegasi)' : ' (Orang Tua)'}';
    return PataraCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: pataraPink.withOpacity(0.12),
            child: Icon(options.categoryIcon(log.category), color: pataraPink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  options.categoryLabel(log.category),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${formatTime(log.at)}$performer',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (log.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(log.description),
                  ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      details.join(' • '),
                      style: const TextStyle(fontSize: 12.5, color: pataraInk),
                    ),
                  ),
                if (log.fromDelegate)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _ValidationChip(status: log.validationStatus, note: log.validationNote),
                  ),
                if (log.photoPath != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showPhoto(log),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Lihat foto bukti'),
                  ),
              ],
            ),
          ),
          if (!widget.isDelegate)
            IconButton(
              tooltip: 'Hapus catatan',
              onPressed: () => _delete(log),
              icon: const Icon(Icons.delete_outline, color: Colors.black38),
            ),
        ],
      ),
    );
  }
}
