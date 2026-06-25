import 'package:flutter/material.dart';
import '../models/child.dart';
import '../services/backend_api_service.dart';
import 'activity_dashboard_screen.dart';

class ActivityTrackerListScreen extends StatefulWidget {
  const ActivityTrackerListScreen({super.key});

  @override
  State<ActivityTrackerListScreen> createState() =>
      _ActivityTrackerListScreenState();
}

class _ActivityTrackerListScreenState extends State<ActivityTrackerListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 Activity Tracker'), elevation: 0),
      body: FutureBuilder<List<Child>>(
        future: _fetchChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data anak: \nsnapshot.error}'),
            );
          }
          final children = snapshot.data ?? [];
          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.child_care, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data anak',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambahkan anak terlebih dahulu untuk mulai tracking aktivitas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              return _buildChildCard(context, child);
            },
          );
        },
      ),
    );
  }

  Future<List<Child>> _fetchChildren() async {
    final backendChildren = await BackendApiService.getChildren();
    return backendChildren
        .map(
          (b) => Child.fromBackend(
            id: b.id,
            userId: '',
            name: b.nama,
            age: b.umur,
          ),
        )
        .toList();
  }

  Widget _buildChildCard(BuildContext context, Child child) {
    final categoryLabel =
        {
          'baby': '👶 Bayi',
          'toddler': '👧 Toddler',
          'balita': '👧 Balita',
          'anak': '👦 Anak',
          'remaja': '👨 Remaja',
        }[child.category] ??
        child.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ActivityDashboardScreen(child: child),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              categoryLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${child.age} tahun',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.calendar_today,
                      'Tracking',
                      'Mulai tracking aktivitas',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      Icons.bar_chart,
                      'Analisis',
                      'Lihat insights perkembangan',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
