import 'package:flutter/material.dart';
import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import '../features/ai_chat_screen.dart';
import '../models/backend_analytics.dart';
import '../services/backend_api_service.dart';

class BackendAnalyticsPanel extends StatefulWidget {
  final int? childId;
  final String title;
  final Color? themeColor;
  final String initialMenuKey;
  final bool showMenuSelector;

  const BackendAnalyticsPanel({
    super.key,
    required this.title,
    this.childId,
    this.themeColor,
    this.initialMenuKey = 'info',
    this.showMenuSelector = true,
  });

  @override
  State<BackendAnalyticsPanel> createState() => _BackendAnalyticsPanelState();
}

class _BackendAnalyticsPanelState extends State<BackendAnalyticsPanel> {
  static const List<String> _menuKeys = ['info', 'ai', 'jadwal', 'akun'];

  String _selectedMenu = 'info';
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  String _selectedTypeFilter = 'Semua';

  Future<_AnalyticsScopeData>? _future;

  @override
  void initState() {
    super.initState();
    _selectedMenu = _normalizeMenuKey(widget.initialMenuKey);
    _future = _load();
  }

  Future<void> _quickAddSchedule(String title, {int hour = 8}) async {
    try {
      final payload = jsonEncode({
        'title': title,
        'scheduleDate': DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          hour,
        ).toIso8601String(),
        'source': 'backend_analytics_panel',
      });
      if (widget.childId != null) {
        await BackendApiService.logActivity(
          childId: widget.childId,
          activityType: 'schedule',
          value: payload,
        );
      } else {
        await BackendApiService.logParentActivity(
          activityType: 'schedule',
          value: payload,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Jadwal "$title" ditambahkan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menambah jadwal: $e')));
    }
  }

  String _normalizeMenuKey(String key) {
    if (_menuKeys.contains(key)) {
      return key;
    }
    return 'info';
  }

  Future<_AnalyticsScopeData> _load() async {
    if (widget.childId != null) {
      final res = await BackendApiService.getChildAnalytics(widget.childId!);
      return _AnalyticsScopeData(
        scopeLabel: '${res.child.nama} (${res.child.umur} th)',
        menus: res.menus,
      );
    }

    final res = await BackendApiService.getParentAnalytics();
    return _AnalyticsScopeData(
      scopeLabel: 'Parent • ${res.childrenCount} anak',
      menus: res.menus,
    );
  }

  String _monthKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  DateTime _shiftMonth(DateTime source, int delta) {
    final monthIndex = (source.year * 12 + source.month - 1) + delta;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    return DateTime(year, month);
  }

  ({Color bg, Color border, Color text}) _colorForType(String label) {
    final normalized = label.toLowerCase();
    var hash = 0;
    for (final code in normalized.codeUnits) {
      hash = (hash * 31 + code) % 360;
    }

    Color fromHsl(double saturation, double lightness) {
      return HSLColor.fromAHSL(
        1,
        hash.toDouble(),
        saturation,
        lightness,
      ).toColor();
    }

    return (
      bg: fromHsl(0.85, 0.93),
      border: fromHsl(0.72, 0.72),
      text: fromHsl(0.52, 0.34),
    );
  }

  String _menuLabel(String key) {
    switch (key) {
      case 'ai':
        return 'AI';
      case 'jadwal':
        return 'Jadwal';
      case 'akun':
        return 'Akun';
      default:
        return 'Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gagal memuat analytics backend: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _future = _load();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        final menu = data.menus[_selectedMenu];
        if (menu == null) {
          return const SizedBox.shrink();
        }

        final monthKey = _monthKey(_visibleMonth);
        final monthCounts = menu.calendarActivityMap[monthKey] ?? const {};
        final monthTypeMap = menu.calendarTypeMap[monthKey] ?? const {};
        final monthDetails = menu.calendarDetailMap[monthKey] ?? const {};

        final totalDays = DateUtils.getDaysInMonth(
          _visibleMonth.year,
          _visibleMonth.month,
        );
        final firstDayWeekday = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          1,
        ).weekday;
        final startOffset = firstDayWeekday - 1;

        final legendCounts = <String, int>{};
        for (final dayTypes in monthTypeMap.values) {
          for (final entry in dayTypes.entries) {
            legendCounts[entry.key] =
                (legendCounts[entry.key] ?? 0) + entry.value;
          }
        }

        final sortedLegend = legendCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final selectedDetails = _selectedDay == null
            ? const <BackendActivityDetail>[]
            : (monthDetails['$_selectedDay'] ??
                  const <BackendActivityDetail>[]);

        final detailTypes = selectedDetails.map((e) => e.type).toSet().toList()
          ..sort();

        final visibleDetails = _selectedTypeFilter == 'Semua'
            ? selectedDetails
            : selectedDetails
                  .where((e) => e.type == _selectedTypeFilter)
                  .toList(growable: false);

        if (_selectedTypeFilter != 'Semua' &&
            !detailTypes.contains(_selectedTypeFilter)) {
          _selectedTypeFilter = 'Semua';
        }

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: widget.themeColor ?? const Color(0xFF7B1FA2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _future = _load();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh analytics',
                    ),
                  ],
                ),
                Text(
                  data.scopeLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (widget.showMenuSelector)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _menuKeys.map((key) {
                      final active = key == _selectedMenu;
                      return ChoiceChip(
                        label: Text(_menuLabel(key)),
                        selected: active,
                        selectedColor:
                            (widget.themeColor ?? const Color(0xFF7B1FA2))
                                .withOpacity(0.22),
                        checkmarkColor:
                            widget.themeColor ?? const Color(0xFF7B1FA2),
                        onSelected: (_) {
                          setState(() {
                            _selectedMenu = key;
                            _selectedDay = null;
                            _selectedTypeFilter = 'Semua';
                          });
                        },
                      );
                    }).toList(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.themeColor ?? const Color(0xFF7B1FA2))
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (widget.themeColor ?? const Color(0xFF7B1FA2))
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Menu ${_menuLabel(_selectedMenu)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: widget.themeColor ?? const Color(0xFF7B1FA2),
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                if (_selectedMenu == 'ai') ...[
                  _AiChatEntryCard(
                    themeColor: widget.themeColor,
                    childId: widget.childId,
                    scopeLabel: data.scopeLabel,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_selectedMenu == 'jadwal') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _quickAddSchedule('Breakfast', hour: 8),
                          child: const Text('Breakfast'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _quickAddSchedule('Lunch', hour: 12),
                          child: const Text('Lunch'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _quickAddSchedule('Dinner', hour: 18),
                          child: const Text('Dinner'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                _WeeklyMiniChart(
                  series: menu.weeklySeries,
                  themeColor: widget.themeColor,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _visibleMonth = _shiftMonth(_visibleMonth, -1);
                          _selectedDay = null;
                          _selectedTypeFilter = 'Semua';
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_visibleMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _visibleMonth = _shiftMonth(_visibleMonth, 1);
                          _selectedDay = null;
                          _selectedTypeFilter = 'Semua';
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const _WeekdayHeader(),
                const SizedBox(height: 6),
                GridView.builder(
                  itemCount: startOffset + totalDays,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    if (index < startOffset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - startOffset + 1;
                    final count = monthCounts['$day'] ?? 0;
                    final typeCounts = monthTypeMap['$day'] ?? const {};
                    final dominantType = _dominantType(typeCounts);

                    final selected = _selectedDay == day;
                    final hasData = count > 0;

                    Color bgColor = Colors.white;
                    Color borderColor = const Color(0xFFDDE7F1);
                    Color textColor = const Color(0xFF455A64);

                    if (hasData && dominantType != null) {
                      final color = _colorForType(dominantType);
                      bgColor = color.bg;
                      borderColor = color.border;
                      textColor = color.text;
                    }

                    if (selected) {
                      borderColor =
                          widget.themeColor ?? const Color(0xFF1E88E5);
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          _selectedTypeFilter = 'Semua';
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: borderColor,
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            if (count > 0)
                              Text(
                                '${count}x',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (sortedLegend.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Legenda warna jenis aktivitas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sortedLegend.take(8).map((entry) {
                      final color = _colorForType(entry.key);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFDDE7F1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: color.border),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${entry.key} (${entry.value})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF455A64),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDay == null
                            ? 'Detail tanggal'
                            : 'Detail tanggal $_selectedDay',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                    if (detailTypes.length > 1)
                      DropdownButton<String>(
                        value: _selectedTypeFilter,
                        items: [
                          const DropdownMenuItem(
                            value: 'Semua',
                            child: Text('Semua jenis'),
                          ),
                          ...detailTypes.map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedTypeFilter = value;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_selectedDay == null)
                  const Text(
                    'Pilih tanggal untuk melihat detail aktivitas.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  )
                else if (visibleDetails.isEmpty)
                  const Text(
                    'Belum ada aktivitas pada tanggal ini.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  )
                else
                  ...visibleDetails.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${detail.text}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _monthLabel(DateTime value) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${names[value.month - 1]} ${value.year}';
  }

  static String? _dominantType(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Row(
      children: labels
          .map(
            (e) => Expanded(
              child: Text(
                e,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _WeeklyMiniChart extends StatelessWidget {
  final Map<String, int> series;
  final Color? themeColor;

  const _WeeklyMiniChart({required this.series, this.themeColor});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = series.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxValue = items.fold<int>(
      0,
      (acc, item) => item.value > acc ? item.value : acc,
    );
    final safeMax = maxValue == 0 ? 1 : maxValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik mini aktivitas 7 hari',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items
                  .map((entry) {
                    final day = DateTime.tryParse(entry.key);
                    final label = day == null
                        ? '?'
                        : _weekdayShort(day.weekday);
                    final height = (entry.value / safeMax) * 52;

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 14,
                            height: height < 6 ? 6 : height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (themeColor ?? const Color(0xFF1E88E5))
                                      .withOpacity(0.45),
                                  themeColor ?? const Color(0xFF1E88E5),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Sen';
      case DateTime.tuesday:
        return 'Sel';
      case DateTime.wednesday:
        return 'Rab';
      case DateTime.thursday:
        return 'Kam';
      case DateTime.friday:
        return 'Jum';
      case DateTime.saturday:
        return 'Sab';
      default:
        return 'Min';
    }
  }
}

class _AnalyticsScopeData {
  final String scopeLabel;
  final Map<String, BackendMenuAnalytics> menus;

  const _AnalyticsScopeData({required this.scopeLabel, required this.menus});
}

class _AiChatEntryCard extends StatelessWidget {
  final Color? themeColor;
  final int? childId;
  final String scopeLabel;

  const _AiChatEntryCard({
    this.themeColor,
    this.childId,
    required this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = themeColor ?? const Color(0xFFF06292);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AiChatScreen(
                childId: childId,
                childName: childId != null
                    ? scopeLabel.split(' (').first
                    : null,
                themeColor: color,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat dengan Patara AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tanya apa saja tentang parenting & anak',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
