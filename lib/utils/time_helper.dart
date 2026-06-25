/// Time-based greeting helper
String getTimeBasedGreeting() {
  final now = DateTime.now();
  final hour = now.hour;

  if (hour >= 5 && hour < 12) {
    return 'Pagi';
  } else if (hour >= 12 && hour < 17) {
    return 'Siang';
  } else if (hour >= 17 && hour < 21) {
    return 'Sore';
  } else {
    return 'Malam';
  }
}

/// Get detailed time period
String getTimePeriod() {
  final now = DateTime.now();
  final hour = now.hour;

  if (hour >= 5 && hour < 12) {
    return 'pagi';
  } else if (hour >= 12 && hour < 17) {
    return 'siang';
  } else if (hour >= 17 && hour < 21) {
    return 'sore';
  } else {
    return 'malam';
  }
}

/// Check if time is morning
bool isMorning() => getTimePeriod() == 'pagi';

/// Check if time is afternoon
bool isAfternoon() => getTimePeriod() == 'siang';

/// Check if time is evening
bool isEvening() => getTimePeriod() == 'sore';

/// Check if time is night
bool isNight() => getTimePeriod() == 'malam';
