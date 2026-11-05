import 'package:flutter/material.dart';

import '../features/anak_mini_games.dart';
import '../features/toddler_mini_games.dart';
import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';
import 'account_tab.dart';
import 'activity_tab.dart';
import 'baby_care_card.dart';
import 'chat_tab.dart';
import 'delegate_tasks_tab.dart';
import 'parent_shell.dart';
import 'guidance_screen.dart';
import 'mission_card.dart';
import 'notification_poller.dart';
import 'announcement_banner.dart';
import 'child_avatar.dart';
import 'patara_ui.dart';

/// Tampilan Delegasi: hanya anak yang ditugaskan, catat aktivitas, dan akun.
class DelegateShell extends StatefulWidget {
  final BackendConnectionStatus status;

  const DelegateShell({super.key, required this.status});

  @override
  State<DelegateShell> createState() => _DelegateShellState();
}

class _DelegateShellState extends State<DelegateShell> {
  late Future<List<BackendChild>> _children;
  final _notifications = NotificationPoller();
  // AI Chat memakai daftar anak yang sama dengan tampilan Orang Tua; bagi Delegasi isinya satu anak.
  final _chatChildren = ChildrenController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _children = BackendApiService.getChildren();
    _chatChildren.reload();
    _notifications.start();
  }

  @override
  void dispose() {
    _notifications.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: switch (_index) {
        0 => sectionAppBar('Aktivitas ${widget.status.childName ?? 'Anak'}', pataraTeal, icon: Icons.assignment_turned_in_outlined),
        1 => sectionAppBar('Tugas dari Orang Tua', pataraTeal, icon: Icons.task_alt),
        2 => sectionAppBar('Tanya AI', pataraTeal, icon: Icons.smart_toy_outlined),
        _ => sectionAppBar('Akun', pataraPurple, icon: Icons.person_outline),
      },
      body: TabFade(index: _index, child: IndexedStack(
        index: _index,
        children: [
          AsyncView<List<BackendChild>>(
            future: _children,
            onRetry: () => setState(() { _children = BackendApiService.getChildren(); }),
            builder: (context, children) {
              if (children.isEmpty) {
                return const EmptyView(
                  icon: Icons.lock_outline,
                  title: 'Akses belum tersedia',
                  message: 'Data anak tidak ditemukan atau akses Anda sudah dicabut oleh Orang Tua.',
                );
              }
              final child = children.first;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DelegateChildPanel(child: child),
                  ),
                  Expanded(child: ActivityHistory(child: child, isDelegate: true)),
                ],
              );
            },
          ),
          AsyncView<List<BackendChild>>(
            future: _children,
            onRetry: () => setState(() { _children = BackendApiService.getChildren(); }),
            builder: (context, children) => children.isEmpty
                ? const EmptyView(
                    icon: Icons.lock_outline,
                    title: 'Akses belum tersedia',
                    message: 'Data anak tidak ditemukan atau akses Anda sudah dicabut oleh Orang Tua.',
                  )
                : DelegateTasksTab(child: children.first),
          ),
          ChatTab(controller: _chatChildren),
          AccountTab(
            isDelegate: true,
            delegateInfo:
                'Anda membantu mencatat aktivitas ${widget.status.childName ?? 'anak'}. '
                'Data anak, laporan, dan pengaturan lain hanya dapat dikelola Orang Tua.',
          ),
        ],
      )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() { _index = index; }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Aktivitas'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Tanya AI'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}

/// Kartu anak untuk Delegasi: identitas anak dan pintasan yang menyesuaikan kelompok usianya
/// (ide stimulasi dan makan sesuai usia, serta permainan untuk Toddler dan Balita).
class DelegateChildPanel extends StatelessWidget {
  final BackendChild child;

  const DelegateChildPanel({super.key, required this.child});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final colors = ageThemeColors(child.category);
    final (guideLabel, guideHint) = switch (child.category) {
      'baby' => ('Stimulasi bayi', 'Sentuhan, suara, tengkurap, dan MPASI'),
      'toddler' => ('Ide usia 1-2 tahun', 'Bermain, bicara, makan'),
      _ => ('Ide usia 2-5 tahun', 'Sensori, cerita, gizi'),
    };
    final Widget? games = switch (child.category) {
      'toddler' => ToddlerMiniGameHubScreen(childId: child.id),
      'balita' => AnakMiniGameHubScreen(childId: child.id),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AnnouncementBanner(),
        MissionCard(child: child),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ChildAvatar(childId: child.id, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${child.ageLabel} • ${child.categoryLabel}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AgeShortcut(
                icon: Icons.lightbulb_outline,
                color: pataraTeal,
                label: guideLabel,
                hint: guideHint,
                onTap: () => _open(context, GuidanceScreen(child: child)),
              ),
            ),
            if (games != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _AgeShortcut(
                  icon: Icons.sports_esports_outlined,
                  color: pataraOrange,
                  label: 'Zona bermain',
                  hint: child.category == 'toddler' ? 'Warna, bentuk, dan buah' : 'Huruf, angka, dan kata',
                  onTap: () => _open(context, games),
                ),
              ),
            ],
          ],
        ),
        if (child.category == 'baby') ...[
          const SizedBox(height: 10),
          BabyCareCard(child: child, isDelegate: true),
        ],
      ],
    );
  }
}

class _AgeShortcut extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _AgeShortcut({
    required this.icon,
    required this.color,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PataraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                ),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
