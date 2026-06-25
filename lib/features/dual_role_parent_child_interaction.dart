// Dual Role Parent–Child Interaction
// Sistem dua peran: Parent Mode & Child Mode

enum UserRole { parent, child }

class DualRoleParentChildInteraction {
  // Implementasi Parent Mode & Child Mode
  UserRole currentRole;

  DualRoleParentChildInteraction({required this.currentRole});

  /// Berpindah peran
  void switchRole(UserRole role) {
    currentRole = role;
  }
}
