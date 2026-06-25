import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';

class MenuInfoTab extends StatefulWidget {
  final int? childId;
  final Color? themeColor;
  final int refreshTick;

  const MenuInfoTab({
    super.key,
    this.childId,
    this.themeColor,
    this.refreshTick = 0,
  });

  @override
  State<MenuInfoTab> createState() => _MenuInfoTabState();
}

class _MenuInfoTabState extends State<MenuInfoTab> {
  late Future<_InfoSummary> _summaryFuture;
  int _selectedRecapMonths = 3;

  @override
  void initState() {
    super.initState();
    _refreshSummary();
  }

  @override
  void didUpdateWidget(covariant MenuInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId ||
        oldWidget.refreshTick != widget.refreshTick) {
      _refreshSummary();
    }
  }

  void _refreshSummary() {
    _summaryFuture = _loadSummary();
  }

  Future<_InfoSummary> _loadSummary() async {
    if (widget.childId != null) {
      final child = await BackendApiService.getChildAnalytics(widget.childId!);
      final info = child.menus['info'];
      if (info == null) {
        throw Exception('Menu info tidak tersedia');
      }

      return _InfoSummary(
        scopeLabel: '${child.child.nama} (${child.child.umur} th)',
        totalActivities: info.totalActivities,
        weekActivities: info.weekActivities,
        monthActivities: info.monthActivities,
        activeDaysWeek: info.activeDaysWeek,
        consistencyRate: info.consistencyRate,
        topActivityType: info.topActivityType,
        activityTypeCount: info.activityTypes.length,
        monthlyRecap: _monthlyRecapFromCalendar(
          info.calendarActivityMap,
          fallbackMonthActivities: info.monthActivities,
        ),
      );
    }

    final parent = await BackendApiService.getParentAnalytics();
    final info = parent.menus['info'];
    if (info == null) {
      throw Exception('Menu info tidak tersedia');
    }

    return _InfoSummary(
      scopeLabel: 'Parent (${parent.childrenCount} anak)',
      totalActivities: info.totalActivities,
      weekActivities: info.weekActivities,
      monthActivities: info.monthActivities,
      activeDaysWeek: info.activeDaysWeek,
      consistencyRate: info.consistencyRate,
      topActivityType: info.topActivityType,
      activityTypeCount: info.activityTypes.length,
      monthlyRecap: _monthlyRecapFromCalendar(
        info.calendarActivityMap,
        fallbackMonthActivities: info.monthActivities,
      ),
    );
  }

  List<_MonthlyRecapItem> _monthlyRecapFromCalendar(
    Map<String, Map<String, int>> calendarMap, {
    required int fallbackMonthActivities,
  }) {
    final totals = <String, int>{};
    for (final monthEntry in calendarMap.entries) {
      totals[monthEntry.key] = monthEntry.value.values.fold<int>(
        0,
        (a, b) => a + b,
      );
    }

    if (totals.isEmpty) {
      final now = DateTime.now();
      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      totals[key] = fallbackMonthActivities;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.reversed
        .map(
          (entry) => _MonthlyRecapItem(monthKey: entry.key, count: entry.value),
        )
        .toList(growable: false);
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${names[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.themeColor ?? const Color(0xFF2196F3);

    return RefreshIndicator(
      onRefresh: () async {
        setState(_refreshSummary);
        await _summaryFuture;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<BackendUser?>(
              future: BackendApiService.getCurrentUser(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final role = user?.role ?? '-';
                return _InfoCard(
                  title: 'Profil Perkembangan',
                  icon: Icons.account_tree_outlined,
                  color: accent,
                  description: 'Role: $role • Email: ${user?.email ?? '-'}',
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<_InfoSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _InfoCard(
                    title: 'Ringkasan Info',
                    icon: Icons.error_outline,
                    color: const Color(0xFFC62828),
                    description: 'Gagal memuat data backend: ${snapshot.error}',
                  );
                }

                final summary = snapshot.data;
                if (summary == null) return const SizedBox.shrink();

                final recapData = summary.monthlyRecap
                    .take(_selectedRecapMonths)
                    .toList(growable: false);
                final maxCount = recapData.isEmpty
                    ? 1
                    : recapData.map((e) => e.count).fold<int>(1, math.max);
                final currentMonth = summary.monthlyRecap.isNotEmpty
                    ? summary.monthlyRecap[0]
                    : null;
                final previousMonth = summary.monthlyRecap.length > 1
                    ? summary.monthlyRecap[1]
                    : null;
                final trendDelta =
                    (currentMonth?.count ?? 0) - (previousMonth?.count ?? 0);
                final trendColor = trendDelta > 0
                    ? const Color(0xFF2E7D32)
                    : trendDelta < 0
                    ? const Color(0xFFC62828)
                    : accent;

                return Column(
                  children: [
                    _InfoCard(
                      title: 'Laporan Perkembangan (${summary.scopeLabel})',
                      icon: Icons.insights_outlined,
                      color: accent,
                      description:
                          'Mingguan: ${summary.weekActivities} • Bulanan: ${summary.monthActivities} • Hari aktif: ${summary.activeDaysWeek}/7',
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      title: 'Insight Aktivitas Teratas',
                      icon: Icons.tips_and_updates_outlined,
                      color: accent,
                      description:
                          'Top aktivitas: ${summary.topActivityType} • Konsistensi: ${summary.consistencyRate}%',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recap Bulanan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [3, 6, 12].map((months) {
                              final selected = _selectedRecapMonths == months;
                              return ChoiceChip(
                                label: Text('$months bulan'),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() => _selectedRecapMonths = months);
                                },
                                selectedColor: accent.withOpacity(0.16),
                                side: BorderSide(
                                  color: accent.withOpacity(
                                    selected ? 0.45 : 0.2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected ? accent : Colors.black87,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          if (currentMonth != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: trendColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: trendColor.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    trendDelta > 0
                                        ? Icons.trending_up
                                        : trendDelta < 0
                                        ? Icons.trending_down
                                        : Icons.trending_flat,
                                    color: trendColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      previousMonth == null
                                          ? 'Belum cukup data untuk membandingkan tren bulan sebelumnya.'
                                          : '${_monthLabel(currentMonth.monthKey)}: ${trendDelta > 0
                                                ? 'Naik $trendDelta aktivitas'
                                                : trendDelta < 0
                                                ? 'Turun ${trendDelta.abs()} aktivitas'
                                                : 'Stabil dibanding bulan lalu'}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: trendColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ...recapData.map((item) {
                            final ratio = maxCount == 0
                                ? 0.0
                                : item.count / maxCount;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _monthLabel(item.monthKey),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${item.count} aktivitas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 7,
                                      color: accent,
                                      backgroundColor: accent.withOpacity(0.14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (recapData.isEmpty)
                            const Text(
                              'Belum ada data recap bulanan.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Progress & Statistik',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Progress mingguan',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: summary.consistencyRate / 100,
                              minHeight: 9,
                              color: accent,
                              backgroundColor: accent.withOpacity(0.14),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${summary.consistencyRate}% konsistensi minggu ini',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatBadge(
                                label: 'Total Aktivitas',
                                value: '${summary.totalActivities}',
                                color: accent,
                              ),
                              _StatBadge(
                                label: 'Aktivitas Bulan Ini',
                                value: '${summary.monthActivities}',
                                color: accent,
                              ),
                              _StatBadge(
                                label: 'Hari Aktif / 7 Hari',
                                value: '${summary.activeDaysWeek}/7',
                                color: accent,
                              ),
                              _StatBadge(
                                label: 'Varian Jenis Aktivitas',
                                value: '${summary.activityTypeCount}',
                                color: accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Preview Mapping Umur',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AgeMappingRow(
                            range: '0-1 tahun',
                            target: 'Dashboard Bayi',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          _AgeMappingRow(
                            range: '1-2 tahun',
                            target: 'Dashboard Toddler',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          _AgeMappingRow(
                            range: '2-5 tahun',
                            target: 'Dashboard Balita',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          _AgeMappingRow(
                            range: '6-12 tahun',
                            target: 'Dashboard Anak',
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSummary {
  final String scopeLabel;
  final int totalActivities;
  final int weekActivities;
  final int monthActivities;
  final int activeDaysWeek;
  final int consistencyRate;
  final String topActivityType;
  final int activityTypeCount;
  final List<_MonthlyRecapItem> monthlyRecap;

  const _InfoSummary({
    required this.scopeLabel,
    required this.totalActivities,
    required this.weekActivities,
    required this.monthActivities,
    required this.activeDaysWeek,
    required this.consistencyRate,
    required this.topActivityType,
    required this.activityTypeCount,
    required this.monthlyRecap,
  });
}

class _MonthlyRecapItem {
  final String monthKey;
  final int count;

  const _MonthlyRecapItem({required this.monthKey, required this.count});
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeMappingRow extends StatelessWidget {
  final String range;
  final String target;
  final Color accent;

  const _AgeMappingRow({
    required this.range,
    required this.target,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            range,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          target,
          style: TextStyle(
            fontSize: 12.5,
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
