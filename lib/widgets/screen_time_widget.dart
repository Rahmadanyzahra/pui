import 'package:flutter/material.dart';
import '../services/screen_time_tracker.dart';

class ScreenTimeWidget extends StatefulWidget {
  final String title;
  final double limitMenit;

  const ScreenTimeWidget({
    super.key,
    this.title = 'Screen Time Hari Ini',
    this.limitMenit = 120,
  });

  @override
  State<ScreenTimeWidget> createState() => _ScreenTimeWidgetState();
}

class _ScreenTimeWidgetState extends State<ScreenTimeWidget> {
  late Future<int> _future;

  @override
  void initState() {
    super.initState();
    _future = ScreenTimeTracker.getTodayScreenTime();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(future: _future, builder: _buildCard);
  }

  Widget _buildCard(BuildContext context, AsyncSnapshot<int> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timer, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final menit = snapshot.data ?? 0;
    final isOver = menit > widget.limitMenit;
    final pct = (menit / widget.limitMenit).clamp(0.0, 1.0);
    final col = isOver ? Colors.red : Colors.amber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, size: 32, color: col),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$menit / ${widget.limitMenit.toInt()} menit',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: col,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(col),
              ),
            ),
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠ Melebihi batas waktu layar!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
