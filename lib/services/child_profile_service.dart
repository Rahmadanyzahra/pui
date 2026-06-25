import '../models/child_profile.dart';
import 'backend_api_service.dart';

class ChildProfileService {
  static Future<String> addChildProfile({
    required String parentId,
    required String name,
    required DateTime birthDate,
    String? photoUrl,
    String? userId,
  }) async {
    try {
      final age = _calculateAge(birthDate);
      final child = await BackendApiService.createChild(nama: name, umur: age);
      return child.id.toString();
    } catch (e) {
      throw Exception('Error adding child profile: $e');
    }
  }

  static Future<List<ChildProfile>> getParentChildren(String parentId) async {
    try {
      final children = await BackendApiService.getChildren();
      return children
          .map(
            (child) => ChildProfile.fromBackend(
              id: child.id,
              parentId: parentId,
              name: child.nama,
              age: child.umur,
              category: _calculateCategory(child.umur),
            ),
          )
          .toList(growable: false);
    } catch (e) {
      throw Exception('Error getting parent children: $e');
    }
  }

  static Future<ChildProfile?> getChildProfile(String childProfileId) async {
    try {
      final children = await BackendApiService.getChildren();
      for (final child in children) {
        if (child.id.toString() == childProfileId) {
          return ChildProfile.fromBackend(
            id: child.id,
            parentId: '',
            name: child.nama,
            age: child.umur,
            category: _calculateCategory(child.umur),
          );
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error getting child profile: $e');
    }
  }

  static Future<void> updateChildProfile(
    String childProfileId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final name = (updates['name'] as String?) ?? '';
      final age = (updates['age'] as int?) ?? 0;
      if (name.isEmpty) {
        throw Exception('name is required');
      }
      await BackendApiService.updateChild(
        childId: int.parse(childProfileId),
        nama: name,
        umur: age,
      );
    } catch (e) {
      throw Exception('Error updating child profile: $e');
    }
  }

  static Future<void> updateChildName(
    String childProfileId,
    String newName,
  ) async {
    try {
      final child = await getChildProfile(childProfileId);
      if (child == null) {
        throw Exception('child not found');
      }
      await updateChildProfile(childProfileId, {
        'name': newName,
        'age': child.age,
      });
    } catch (e) {
      throw Exception('Error updating child name: $e');
    }
  }

  static Future<void> deleteChildProfile(String childProfileId) async {
    try {
      await BackendApiService.deleteChild(int.parse(childProfileId));
    } catch (e) {
      throw Exception('Error deleting child profile: $e');
    }
  }

  static Future<void> connectRemajaTOParent(
    String childProfileId,
    String parentId,
    String userId,
  ) async {
    try {
      final child = await getChildProfile(childProfileId);
      if (child == null) {
        throw Exception('child not found');
      }
      await updateChildProfile(childProfileId, {
        'name': child.name,
        'age': child.age,
      });
    } catch (e) {
      throw Exception('Error connecting remaja to parent: $e');
    }
  }

  static Future<List<ChildProfile>> getChildrenByCategory(
    String parentId,
    String category,
  ) async {
    try {
      final children = await getParentChildren(parentId);
      return children.where((child) => child.category == category).toList();
    } catch (e) {
      throw Exception('Error getting children by category: $e');
    }
  }

  static Stream<List<ChildProfile>> streamParentChildren(String parentId) {
    return Stream<List<ChildProfile>>.periodic(
      const Duration(seconds: 3),
    ).asyncMap((_) => getParentChildren(parentId));
  }

  static Future<int> getParentChildrenCount(String parentId) async {
    try {
      final children = await getParentChildren(parentId);
      return children.length;
    } catch (e) {
      throw Exception('Error getting parent children count: $e');
    }
  }

  static int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
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
}
