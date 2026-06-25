// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SchedulePreviewCard extends StatelessWidget {
  final int? childId;
  final Color? themeColor;
  final String title;

  const SchedulePreviewCard({
    super.key,
    this.childId,
    this.themeColor,
    this.title = 'Jadwal Terdekat',
  });

  // String _formatDate(DateTime date) {
  //   final d = date.day.toString().padLeft(2, '0');
  //   final m = date.month.toString().padLeft(2, '0');
  //   return '$d/$m/${date.year}';
  // }

  @override
  Widget build(BuildContext context) {
    final accent = themeColor ?? const Color(0xFFF06292);
    return Container(
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
          Row(
            children: [
              Icon(Icons.event_note_outlined, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Jadwal akan ditampilkan di sini setelah integrasi backend. (TODO)',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
