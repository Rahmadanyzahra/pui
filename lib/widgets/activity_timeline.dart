import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_activity.dart';
import '../services/activity_tracking_service.dart';

class ActivityTimeline extends StatefulWidget {
  final String childId;
  final DateTime date;

  const ActivityTimeline({
    super.key,
    required this.childId,
    required this.date,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailyActivity>>(
      stream: ActivityTrackingService.streamActivitiesByDate(
        widget.childId,
        widget.date,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada aktivitas hari ini',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mulai tambahkan aktivitas untuk mulai tracking',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        // Group activities by time
        activities.sort((a, b) => a.date.compareTo(b.date));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final isLast = index == activities.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: _ActivityTimelineItem(
                activity: activity,
                isLast: isLast,
                isFirst: index == 0,
                onDelete: () => _deleteActivity(activity.id!),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteActivity(String activityId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Aktivitas'),
        content: const Text('Apakah Anda yakin ingin menghapus aktivitas ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ActivityTrackingService.deleteActivity(activityId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivitas berhasil dihapus')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  final DailyActivity activity;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onDelete;

  const _ActivityTimelineItem({
    required this.activity,
    required this.isLast,
    required this.isFirst,
    required this.onDelete,
  });

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'feeding':
        return Icons.restaurant;
      case 'meal':
        return Icons.lunch_dining;
      case 'sleep':
        return Icons.bedtime;
      case 'activity':
        return Icons.sports_soccer;
      case 'parenting':
        return Icons.psychology;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'feeding':
        return const Color(0xFFFF9800);
      case 'meal':
        return const Color(0xFF8BC34A);
      case 'sleep':
        return const Color(0xFF2196F3);
      case 'activity':
        return const Color(0xFFE91E63);
      case 'parenting':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final color = _getActivityColor(activity.activityType);

    return Row(
      crossAxisAlignment: isLast
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.start,
      children: [
        // Timeline dot
        Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                _getActivityIcon(activity.activityType),
                color: color,
                size: 28,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: color.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Activity details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DailyActivity.getActivityLabel(activity.activityType),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeFormat.format(activity.date),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: onDelete,
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Activity details container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration
                    if (activity.durationMinutes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${activity.durationMinutes} menit',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Description
                    if (activity.description != null &&
                        activity.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activity.description!,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Quantity & Unit
                    if (activity.quantity != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.scale, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${activity.quantity} ${activity.unit ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Breastfeeding indicator
                    if (activity.isBreastfeeding != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activity.isBreastfeeding!
                                  ? Icons.favorite
                                  : Icons.local_drink,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.isBreastfeeding! ? 'ASI' : 'Botol',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Mood
                    if (activity.moodBefore != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_emotions,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${DailyActivity.getMoodLabel(activity.moodBefore!)} → ${activity.moodAfter != null ? DailyActivity.getMoodLabel(activity.moodAfter!) : 'tidak dicatat'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Rating
                    if (activity.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${activity.rating}/5',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    // Notes
                    if (activity.notes != null && activity.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note_alt, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activity.notes!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
