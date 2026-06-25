/// Child profile untuk Bayi dan Toddler (tanpa akun user sendiri)
/// parent_id = current_user, user_id = NULL
class ChildProfile {
  final String id;
  final String parentId; // Parent yang manage child ini
  final String? userId; // NULL untuk Bayi/Toddler, terisi untuk Remaja
  final String name;
  final DateTime birthDate;
  final int age;
  final String category; // 'baby', 'toddler', 'remaja'
  final String? photoUrl;
  final bool isConnected; // Untuk remaja: sudah terhubung dengan parent?
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChildProfile({
    required this.id,
    required this.parentId,
    this.userId,
    required this.name,
    required this.birthDate,
    required this.age,
    required this.category,
    this.photoUrl,
    this.isConnected = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChildProfile.fromBackend({
    required int id,
    required String parentId,
    String? userId,
    required String name,
    required int age,
    String? category,
    String? photoUrl,
    bool isConnected = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final birthDate = DateTime.now().subtract(Duration(days: age * 365));
    return ChildProfile(
      id: id.toString(),
      parentId: parentId,
      userId: userId,
      name: name,
      birthDate: birthDate,
      age: age,
      category: category ?? 'baby',
      photoUrl: photoUrl,
      isConnected: isConnected,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ChildProfile copyWith({
    String? id,
    String? parentId,
    String? userId,
    String? name,
    DateTime? birthDate,
    int? age,
    String? category,
    String? photoUrl,
    bool? isConnected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      category: category ?? this.category,
      photoUrl: photoUrl ?? this.photoUrl,
      isConnected: isConnected ?? this.isConnected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
