import 'package:cloud_firestore/cloud_firestore.dart';

class Child {
  final String id;
  final String userId;
  final String name;
  final DateTime birthDate;
  final int age;
  final String category;

  Child({
    required this.id,
    required this.userId,
    required this.name,
    required this.birthDate,
  }) : age = _calculateAge(birthDate),
       category = _calculateCategory(_calculateAge(birthDate));

  static int _calculateAge(DateTime birthDate) {
    DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String _calculateCategory(int age) {
    if (age <= 1) return 'baby';
    if (age <= 2) return 'toddler';
    if (age <= 5) return 'balita';
    if (age <= 12) return 'anak';
    return 'remaja';
  }

  factory Child.fromBackend({
    required int id,
    required String userId,
    required String name,
    required int age,
  }) {
    final birthDate = DateTime.now().subtract(Duration(days: age * 365));
    return Child(
      id: id.toString(),
      userId: userId,
      name: name,
      birthDate: birthDate,
    );
  }

  factory Child.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Child(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Unknown',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
