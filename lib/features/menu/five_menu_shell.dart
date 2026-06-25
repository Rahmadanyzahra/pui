import 'package:flutter/material.dart';

import '../../services/dashboard_theme_service.dart';

import 'menu_akun_tab.dart';
import 'menu_ai_tab.dart';
import 'menu_dashboard_tab.dart';
import 'menu_info_tab.dart';
import 'menu_jadwal_tab.dart';

class FiveMenuShell extends StatefulWidget {
  final int? childId;
  final Color? themeColor;
  final String titlePrefix;
  final String? dashboardType;
  final int initialIndex;
  final List<String>? assignedChildren;
  final String? linkedParentUid;

  const FiveMenuShell({
    super.key,
    this.childId,
    this.themeColor,
    required this.titlePrefix,
    this.dashboardType,
    this.initialIndex = 0,
    this.assignedChildren,
    this.linkedParentUid,
  });

  @override
  State<FiveMenuShell> createState() => _FiveMenuShellState();
}

class _FiveMenuShellState extends State<FiveMenuShell> {
  late int _currentIndex;
  late DashboardThemeProfile _themeProfile;
  int _infoRefreshTick = 0;
  bool get _showAiTab => widget.childId == null;

  static const List<String> _parentTitles = [
    'Dashboard',
    'Info',
    'AI',
    'Jadwal',
    'Akun',
  ];

  static const List<String> _childTitles = [
    'Dashboard',
    'Info',
    'Jadwal',
    'Akun',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _visibleTitles.length - 1);
    _themeProfile = DashboardThemeProfile.defaultTheme(
      widget.dashboardType ?? 'parent',
    );
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    if (widget.dashboardType == null) return;
    final theme = await DashboardThemeService.getTheme(widget.dashboardType!);
    if (!mounted) return;
    setState(() {
      _themeProfile = theme;
    });
  }

  List<String> get _visibleTitles => _showAiTab ? _parentTitles : _childTitles;

  List<Widget> get _pages {
    final activeColor = widget.dashboardType != null
        ? _themeProfile.primaryColor
        : (widget.themeColor ?? const Color(0xFFF06292));

    final pages = <Widget>[
      MenuDashboardTab(
        childId: widget.childId,
        themeColor: activeColor,
        assignedChildren: widget.assignedChildren,
        linkedParentUid: widget.linkedParentUid,
      ),
      MenuInfoTab(
        childId: widget.childId,
        themeColor: activeColor,
        refreshTick: _infoRefreshTick,
      ),
      if (_showAiTab)
        MenuAiTab(childId: widget.childId, themeColor: activeColor),
      MenuJadwalTab(childId: widget.childId, themeColor: activeColor),
      MenuAkunTab(childId: widget.childId, themeColor: activeColor),
    ];

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.dashboardType != null
        ? _themeProfile.primaryColor
        : (widget.themeColor ?? const Color(0xFFF06292));

    final themedData = Theme.of(context).copyWith(
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: _themeProfile.fontFamily),
      primaryTextTheme: Theme.of(
        context,
      ).primaryTextTheme.apply(fontFamily: _themeProfile.fontFamily),
      appBarTheme: Theme.of(context).appBarTheme.copyWith(
        backgroundColor: activeColor,
        foregroundColor: Colors.white,
      ),
    );

    return Theme(
      data: themedData,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.titlePrefix} • ${_visibleTitles[_currentIndex]}',
          ),
        ),
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          indicatorColor: activeColor.withOpacity(0.2),
          onDestinationSelected: (index) {
            setState(() {
              if (index == 1) {
                _infoRefreshTick++;
              }
              _currentIndex = index;
            });
          },
          destinations: _showAiTab
              ? const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.info_outline),
                    selectedIcon: Icon(Icons.info),
                    label: 'Info',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_toy_outlined),
                    selectedIcon: Icon(Icons.smart_toy),
                    label: 'AI',
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
                ]
              : const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.info_outline),
                    selectedIcon: Icon(Icons.info),
                    label: 'Info',
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
      ),
    );
  }
}
