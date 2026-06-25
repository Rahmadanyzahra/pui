// Activity & Reward System
// Sistem reward/poin untuk motivasi anak

class ActivityRewardSystem {
  // Implementasi sistem reward dan poin

  int points = 0;

  /// Menambah poin untuk aktivitas positif
  void addPoints(int value) {
    points += value;
  }

  /// Mendapatkan total poin
  int getPoints() => points;
}
