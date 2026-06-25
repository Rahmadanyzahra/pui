import 'package:flutter/material.dart';
import 'child_dashboard_screen.dart';

class AgeGroupSelectionScreen extends StatefulWidget {
  final String role;

  const AgeGroupSelectionScreen({super.key, required this.role});

  @override
  State<AgeGroupSelectionScreen> createState() =>
      _AgeGroupSelectionScreenState();
}

class _AgeGroupSelectionScreenState extends State<AgeGroupSelectionScreen> {
  final List<Map<String, dynamic>> ageGroups = [
    {
      'id': 'baby',
      'name': 'Bayi',
      'range': '0-1 Tahun',
      'icon': Icons.child_care,
      'color': Color(0xFFFF69B4),
    },
    {
      'id': 'toddler',
      'name': 'Toddler',
      'range': '1-2 Tahun',
      'icon': Icons.toys,
      'color': Color(0xFFFF1493),
    },
    {
      'id': 'balita',
      'name': 'Balita',
      'range': '2-5 Tahun',
      'icon': Icons.school,
      'color': Color(0xFFBA68C8),
    },
    {
      'id': 'anak',
      'name': 'Anak',
      'range': '6-12 Tahun',
      'icon': Icons.menu_book,
      'color': Color(0xFF64B5F6),
    },
  ];

  int _ageForGroup(String ageGroupId) {
    switch (ageGroupId) {
      case 'baby':
        return 1;
      case 'toddler':
        return 2;
      case 'balita':
        return 4;
      case 'anak':
        return 8;
      default:
        return 4;
    }
  }

  void _selectAgeGroup(String ageGroupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildDashboardScreen(
          category: ageGroupId,
          umur: _ageForGroup(ageGroupId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.role == 'parent' ? 'Pilih Golongan Usia' : 'Pilih Usia Anda',
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                widget.role == 'parent'
                    ? 'Pilih golongan usia anak yang ingin dikelola'
                    : 'Pilih usia Anda',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ageGroups.length,
                itemBuilder: (context, index) {
                  final group = ageGroups[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _selectAgeGroup(group['id']),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                group['color'],
                                group['color'].withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: group['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group['name'],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      group['range'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                group['icon'],
                                size: 48,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
