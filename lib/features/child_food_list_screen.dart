import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/child_food_service.dart';

class ChildFoodListScreen extends StatelessWidget {
  final String childId;
  const ChildFoodListScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Makanan')),
      body: FutureBuilder<List<dynamic>>(
        future: ChildFoodService.fetchFoods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada catatan makanan'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final docId = item['_id']?.toString() ?? '';
              final ts =
                  DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
                  DateTime.now();
              final name = item['name'] ?? '';
              return ListTile(
                title: Text(name),
                subtitle: Text('${ts.toLocal()}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus catatan'),
                        content: const Text('Hapus catatan makanan ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await ChildFoodService.deleteFood(docId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Terhapus')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal hapus: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
