// Parenting Reminder
// Pengingat jadwal belajar, tidur, screen time, aktivitas keluarga

class ParentingReminder {
  // Implementasi fitur pengingat parenting

  final List<String> reminders = [];

  /// Menambah pengingat baru
  void addReminder(String reminder) {
    reminders.add(reminder);
  }

  /// Mendapatkan semua pengingat
  List<String> getAllReminders() => reminders;
}
