import 'package:flutter/material.dart';

/// Activity Stats Card - Modern activity metrics display for babies and toddlers
class ActivityStatsCard extends StatelessWidget {
  final String title;
  final String icon;
  final String value;
  final String subtitle;
  final Color primaryColor;
  final Color backgroundColor;
  final IconData? iconData;
  final VoidCallback? onTap;

  const ActivityStatsCard({
    super.key,
    required this.title,
    this.icon = '',
    required this.value,
    this.subtitle = '',
    this.primaryColor = const Color(0xFFF06292),
    this.backgroundColor = const Color(0xFFF3E5F5),
    this.iconData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                      Row(
                        children: [
                          if (iconData != null)
                            Icon(iconData, color: primaryColor, size: 18),
                          if (iconData != null) const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (icon.isNotEmpty)
                  Text(icon, style: const TextStyle(fontSize: 40)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Activity Highlights Section - Shows main activity with mascot
class ActivityHighlights extends StatelessWidget {
  final String activityName;
  final int percentage;
  final String duration;
  final String caloriesBurned;
  final String date;
  final String emoji;
  final Color accentColor;
  final VoidCallback? onViewCalendar;

  const ActivityHighlights({
    super.key,
    required this.activityName,
    required this.percentage,
    required this.duration,
    required this.caloriesBurned,
    required this.date,
    this.emoji = '🐰',
    this.accentColor = const Color(0xFF9C27B0),
    this.onViewCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.15),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mascot and activity display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - activity info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Right side - mascot emoji
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 48)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Activity details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$caloriesBurned • $duration',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: accentColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // View calendar button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onViewCalendar,
              icon: Icon(Icons.calendar_today, size: 16, color: accentColor),
              label: Text(
                'Lihat Kalender Aktivitas',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity Metrics Grid - Multiple metrics in grid layout
class ActivityMetricsGrid extends StatelessWidget {
  final List<ActivityMetric> metrics;
  final int crossAxisCount;

  const ActivityMetricsGrid({
    super.key,
    required this.metrics,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: metrics
          .map(
            (metric) => ActivityStatsCard(
              title: metric.title,
              icon: metric.icon,
              value: metric.value,
              subtitle: metric.subtitle,
              primaryColor: metric.color,
              backgroundColor: metric.color.withOpacity(0.1),
              iconData: metric.iconData,
              onTap: metric.onTap,
            ),
          )
          .toList(),
    );
  }
}

/// Activity Metric data class
class ActivityMetric {
  final String title;
  final String icon;
  final String value;
  final String subtitle;
  final Color color;
  final IconData? iconData;
  final VoidCallback? onTap;

  ActivityMetric({
    required this.title,
    this.icon = '',
    required this.value,
    this.subtitle = '',
    this.color = const Color(0xFFF06292),
    this.iconData,
    this.onTap,
  });
}
