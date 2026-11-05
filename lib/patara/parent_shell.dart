import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'account_tab.dart';
import 'activity_tab.dart';
import 'chat_tab.dart';
import 'home_tab.dart';
import 'notification_poller.dart';
import 'patara_ui.dart';
import 'schedule_tab.dart';

/// Daftar anak dan anak yang sedang dipilih, dipakai bersama oleh semua tab.
class ChildrenController extends ChangeNotifier {
  List<BackendChild> children = const [];
  String? selectedId;
  bool loading = true;
  String? error;

  BackendChild? get selected {
    for (final child in children) {
      if (child.id == selectedId) return child;
    }
    return children.isEmpty ? null : children.first;
  }

  Future<void> reload({String? select}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      children = await BackendApiService.getChildren();
      if (select != null) selectedId = select;
      if (!children.any((child) => child.id == selectedId)) {
        selectedId = children.isEmpty ? null : children.first.id;
      }
    } catch (e) {
      error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    }
    loading = false;
    notifyListeners();
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }
}

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  final _children = ChildrenController();
  final _notifications = NotificationPoller();
  int _index = 0;

  static const _titles = ['TARA', 'Aktivitas', 'AI Chat', 'Jadwal', 'Akun'];
  static const _colors = [pataraPink, pataraPink, pataraTeal, pataraBlue, pataraPurple];
  static const _icons = [Icons.home, Icons.edit_note, Icons.smart_toy_outlined, Icons.calendar_month, Icons.person_outline];

  @override
  void initState() {
    super.initState();
    _children.reload();
    _notifications.start();
  }

  @override
  void dispose() {
    _notifications.stop();
    _children.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Beranda memakai kepala halaman bergradasi sendiri.
      appBar: _index == 0 ? null : sectionAppBar(_titles[_index], _colors[_index], icon: _icons[_index]),
      body: TabFade(index: _index, child: IndexedStack(
        index: _index,
        children: [
          HomeTab(
            controller: _children,
            onOpenTab: (index) => setState(() { _index = index; }),
          ),
          ActivityTab(controller: _children),
          ChatTab(controller: _children),
          ScheduleTab(controller: _children),
          const AccountTab(),
        ],
      )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() { _index = index; }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Aktivitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Jadwal',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

/// Pemilih anak berbentuk chip yang dipakai di bagian atas tiap tab.
class ChildSelector extends StatelessWidget {
  final ChildrenController controller;
  final VoidCallback? onAdd;

  const ChildSelector({super.key, required this.controller, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final child in controller.children)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(child.nama),
                selected: child.id == selected?.id,
                onSelected: (_) => controller.select(child.id),
              ),
            ),
          if (onAdd != null)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Tambah anak'),
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}
