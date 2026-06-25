import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/child.dart';
import '../models/child_analysis.dart';
import '../services/activity_tracking_service.dart';
import '../services/analysis_service.dart';
import '../widgets/activity_input_form.dart';
import '../widgets/activity_timeline.dart';
import 'dashboard_back_navigation.dart';

class ActivityDashboardScreen extends StatefulWidget {
  final Child child;
  final bool openedFromParentDashboard;

  const ActivityDashboardScreen({
    super.key,
    required this.child,
    this.openedFromParentDashboard = false,
  });

  @override
  State<ActivityDashboardScreen> createState() =>
      _ActivityDashboardScreenState();
}

class _ActivityDashboardScreenState extends State<ActivityDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _isGeneratingAnalysis = false;
  ChildAnalysis? _latestAnalysis;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLatestAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestAnalysis() async {
    final analysis = await AnalysisService.getLatestAnalysis(widget.child.id);
    if (mounted) {
      setState(() => _latestAnalysis = analysis);
    }
  }

  Future<void> _generateAnalysis() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Analisis'),
        content: const Text(
          'Proses analisis akan menggunakan semua data aktivitas dari 30 hari terakhir. Pastikan Anda memiliki cukup data untuk analisis yang akurat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isGeneratingAnalysis = true);

    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final activities = await ActivityTrackingService.getActivitiesInPeriod(
        widget.child.id,
        thirtyDaysAgo,
        DateTime.now(),
      );

      if (activities.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belum ada data aktivitas untuk dianalisis'),
          ),
        );
        return;
      }

      final analysis = await AnalysisService.generateAnalysis(
        widget.child.id,
        widget.child.userId,
        activities,
      );

      await AnalysisService.saveAnalysis(analysis);

      if (!mounted) return;
      setState(() => _latestAnalysis = analysis);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analisis berhasil dibuat!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAnalysis = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: Text('Aktivitas ${widget.child.name}'),
        leading: widget.openedFromParentDashboard
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigateBackToParentDashboard(
                  context,
                  openedFromParentDashboard: true,
                ),
              )
            : null,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Hari Ini'),
            Tab(icon: Icon(Icons.history), text: 'Timeline'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Analisis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Input Aktivitas
          ActivityInputForm(
            childId: widget.child.id,
            childName: widget.child.name,
            childAge: widget.child.age,
            onActivityAdded: () {
              _loadLatestAnalysis();
            },
          ),

          // Tab 2: Timeline Aktivitas
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateFormat.format(_selectedDate),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(
                          () => _selectedDate = _selectedDate.subtract(
                            Duration(days: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: _selectedDate.isBefore(DateTime.now())
                          ? () {
                              setState(
                                () => _selectedDate = _selectedDate.add(
                                  Duration(days: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ActivityTimeline(
                  childId: widget.child.id,
                  date: _selectedDate,
                ),
              ),
            ],
          ),

          // Tab 3: Analisis dan Insights
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Check if 30 days of data
                FutureBuilder<bool>(
                  future: ActivityTrackingService.has30DaysOfData(
                    widget.child.id,
                  ),
                  builder: (context, snapshot) {
                    final has30Days = snapshot.data ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: has30Days
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            border: Border.all(
                              color: has30Days ? Colors.green : Colors.orange,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    has30Days ? Icons.check_circle : Icons.info,
                                    color: has30Days
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      has30Days
                                          ? 'Anda memiliki cukup data untuk analisis AI'
                                          : 'Perlu minimal 30 hari data untuk analisis',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              if (!has30Days)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Terus tracking aktivitas harian untuk mendapatkan insights yang lebih akurat',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (has30Days)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isGeneratingAnalysis
                                  ? null
                                  : _generateAnalysis,
                              icon: _isGeneratingAnalysis
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: Text(
                                _isGeneratingAnalysis
                                    ? 'Memproses...'
                                    : 'Generate Analisis AI',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Display Analysis Results
                if (_latestAnalysis != null) ...[
                  // Sleep Quality Card
                  _buildPremiumStatCard(
                    context: context,
                    title: '😴 Kualitas Tidur',
                    gradient: [Colors.blue.shade400, Colors.blue.shade700],
                    child: Column(
                      children: [
                        _buildCircularStat(
                          percentage:
                              (_latestAnalysis!.avgSleepDurationHours ?? 0) /
                              18 *
                              100,
                          duration:
                              '${_latestAnalysis!.avgSleepDurationHours ?? 0}h',
                          label: 'Rata-rata Durasi',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatBadge(
                              icon: Icons.repeat_one,
                              value:
                                  '${_latestAnalysis!.totalSleepSessions ?? 0}x',
                              label: 'Sesi Tidur',
                              color: Colors.blue,
                            ),
                            _buildStatBadge(
                              icon: Icons.bar_chart,
                              value:
                                  _latestAnalysis!.sleepPattern?.contains(
                                        'Consolidated',
                                      ) ??
                                      false
                                  ? 'Baik'
                                  : 'Normal',
                              label: 'Pola Tidur',
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _latestAnalysis!.sleepQualityAssessment ??
                                'Data tidur terukur dengan baik',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Activity Card
                  _buildPremiumStatCard(
                    context: context,
                    title: '🎮 Aktivitas & Perkembangan',
                    gradient: [Colors.purple.shade400, Colors.purple.shade700],
                    child: Column(
                      children: [
                        _buildCircularStat(
                          percentage:
                              ((_latestAnalysis!.avgActivityDurationMin ?? 0) /
                                      60 *
                                      100)
                                  .clamp(0, 100),
                          duration:
                              '${_latestAnalysis!.avgActivityDurationMin ?? 0}m',
                          label: 'Durasi Aktivitas',
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatBadge(
                              icon: Icons.trending_up,
                              value:
                                  (_latestAnalysis!.activityLevel
                                      ?.toUpperCase() ??
                                  'NORMAL'),
                              label: 'Level Aktivitas',
                              color: Colors.purple,
                            ),
                            if ((_latestAnalysis!.favoriteActivities?.length ??
                                    0) >
                                0)
                              _buildStatBadge(
                                icon: Icons.favorite,
                                value:
                                    '${(_latestAnalysis!.favoriteActivities?.length ?? 0)} Fav',
                                label: 'Aktivitas Favorit',
                                color: Colors.purple,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if ((_latestAnalysis!.favoriteActivities?.isNotEmpty ??
                            false))
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                (_latestAnalysis!.favoriteActivities ?? [])
                                    .take(3)
                                    .map(
                                      (activity) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          activity,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feeding Card
                  _buildPremiumStatCard(
                    context: context,
                    title: '🍼 Menyusui & Nutrisi',
                    gradient: [Colors.orange.shade400, Colors.orange.shade700],
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatBadge(
                              icon: Icons.schedule,
                              value:
                                  '${(_latestAnalysis!.avgFeedingFrequencyPerDay ?? 0).toStringAsFixed(1)}x',
                              label: 'Frekuensi/Hari',
                              color: Colors.orange,
                            ),
                            _buildStatBadge(
                              icon: Icons.timer,
                              value:
                                  '${(_latestAnalysis!.avgBreastfeedingDurationMin ?? 0).toInt()}m',
                              label: 'Durasi ASI',
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_latestAnalysis!.mealsPerDay != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Makan ${_latestAnalysis!.mealsPerDay}x sehari - Pola makan teratur',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Behavior Card
                  _buildPremiumStatCard(
                    context: context,
                    title: '😊 Perilaku & Mood',
                    gradient: [Colors.pink.shade400, Colors.pink.shade700],
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Icon(
                                    Icons.emoji_emotions,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _latestAnalysis!.moodPattern ?? 'Tenang',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(
                                    Icons.sentiment_satisfied,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_latestAnalysis!.fussyEpisodesPerDay ?? 0}x rewel',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
                  if ((_latestAnalysis!.recommendations?.isNotEmpty ?? false))
                    _buildPremiumStatCard(
                      context: context,
                      title: '💡 Rekomendasi',
                      gradient: [Colors.amber.shade400, Colors.amber.shade700],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (_latestAnalysis!.recommendations ?? [])
                            .asMap()
                            .entries
                            .map((entry) {
                              final index = entry.key;
                              final rec = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index <
                                          ((_latestAnalysis!
                                                      .recommendations
                                                      ?.length ??
                                                  0) -
                                              1)
                                      ? 12
                                      : 0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        rec,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              height: 1.4,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // AI Insights
                  if (_latestAnalysis!.aiInsights != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI Analysis Insights',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _latestAnalysis!.aiInsights!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white, height: 1.6),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Confidence: ${_latestAnalysis!.confidenceScore ?? 85}%',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.analytics,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Analisis',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate analisis pertama Anda untuk melihat insights tentang perkembangan anak',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required BuildContext context,
    required String title,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCircularStat({
    required double percentage,
    required String duration,
    required String label,
    required Color color,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: (percentage / 100).clamp(0, 1),
            strokeWidth: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              duration,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
