import 'package:flutter/material.dart';
import 'package:patara_ai/features/add_child_screen.dart';

// A cleaned, minimal, and compilable dashboard menu screen.
// TODO: integrate real services (ChildProfileService, BackendApiService) later.

class DashboardMenuScreen extends StatefulWidget {
  const DashboardMenuScreen({super.key});

  @override
  State<DashboardMenuScreen> createState() => _DashboardMenuScreenState();
}

class _DashboardMenuScreenState extends State<DashboardMenuScreen> {
  late Future<int> _childCountFuture;
  late Future<List<Map<String, dynamic>>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    // Use placeholder values for now. Integrate backend services in next step.
    _childCountFuture = Future.value(0);
    _childrenFuture = Future.value(<Map<String, dynamic>>[]);
  }

  void _openFamilyDashboardPicker(
    BuildContext context, {
    required int childCount,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.child_care),
                  title: const Text('Bayi'),
                  subtitle: Text('Kelola semua anak ($childCount)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buka Dashboard Bayi')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.face),
                  title: const Text('Toddler'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buka Dashboard Toddler')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group),
                  title: const Text('Balita / Anak'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buka Dashboard Balita / Anak'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChildProfilesSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Gagal memuat daftar anak: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final children = snapshot.data ?? <Map<String, dynamic>>[];
        if (children.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Belum ada anak tersimpan. Tambahkan anak untuk menampilkannya di sini.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return Column(
          children: children.map((child) {
            final name = child['name'] ?? '-';
            final age = child['age']?.toString() ?? '-';
            final category = child['category'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Buka dashboard untuk $name')),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FCFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD7E2EE)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '-',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$category • $age th',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 380;
    final screenHeight = MediaQuery.of(context).size.height;
    final spacing = isCompact ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Anda yakin ingin keluar?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(c);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Logout')));
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.04),
            Text(
              'Selamat Datang di Patara AI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF06292),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing),
            Text(
              'Pilih aksi yang ingin Anda lakukan',
              style: TextStyle(
                fontSize: isCompact ? 13 : 15,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.06),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: [
                FutureBuilder<int>(
                  future: _childCountFuture,
                  builder: (context, snapshot) {
                    final childCount = snapshot.data ?? 0;
                    return StatusMenuButton(
                      icon: Icons.dashboard_customize,
                      label: 'Dashboard Keluarga',
                      subtitle: 'Bayi • Toddler • Parent',
                      color: const Color(0xFFF06292),
                      badge: childCount > 0
                          ? StatusBadge(
                              text: childCount.toString(),
                              color: Colors.green,
                            )
                          : null,
                      onTap: () => _openFamilyDashboardPicker(
                        context,
                        childCount: childCount,
                      ),
                    );
                  },
                ),
                StatusMenuButton(
                  icon: Icons.person_add,
                  label: 'Tambah Anak',
                  subtitle: 'Tambah profil anak',
                  color: const Color(0xFF00BCD4),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddChildScreen()),
                    );
                    if (result is Map && result['saved'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Anak berhasil ditambahkan'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.06),
            _buildChildProfilesSection(),
            SizedBox(height: screenHeight * 0.04),
            Container(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tips Penggunaan',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                          fontSize: isCompact ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Gunakan tombol "Tambah Anak" untuk menambahkan data anak\n• Akses dashboard untuk melihat semua anak\n• Sinkronkan backend untuk data real-time',
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 12,
                      color: Colors.blue.shade700,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  const StatusMenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (badge != null) Positioned(top: 8, right: 8, child: badge!),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({required this.text, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
