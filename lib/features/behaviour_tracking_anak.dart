// Behaviour Tracking Anak
// Fitur pencatatan dan pemantauan perilaku anak

class BehaviourTrackingAnak {
  // Implementasi tracking kebiasaan belajar, bermain, gadget, emosi

  final List<Map<String, dynamic>> behaviourLog = [];

  /// Mencatat perilaku harian anak
  void trackBehaviour(Map<String, dynamic> behaviour) {
    behaviourLog.add(behaviour);
  }

  /// Mendapatkan seluruh data perilaku
  List<Map<String, dynamic>> getAllBehaviour() => behaviourLog;
}
