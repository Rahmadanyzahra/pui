class ChildAge {
  const ChildAge({
    required this.years,
    required this.months,
    required this.days,
    required this.category,
  });

  final int years;
  final int months;
  final int days;
  final String category;

  int get totalMonths => years * 12 + months;

  String get formatted => '$years tahun $months bulan $days hari';

  static DateTime jakartaToday({DateTime? now}) {
    final instant = now ?? DateTime.now();
    final jakarta = instant.toUtc().add(const Duration(hours: 7));
    return DateTime(jakarta.year, jakarta.month, jakarta.day);
  }

  static ChildAge? calculate(DateTime birthDate, {DateTime? now}) {
    final today = jakartaToday(now: now);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    if (birth.isAfter(today)) return null;

    var years = today.year - birth.year;
    if (_compareMonthDay(today, birth) < 0) years--;

    final anniversaryYear = birth.year + years;
    final anniversaryDay = _clampDay(anniversaryYear, birth.month, birth.day);
    final anniversary = DateTime(anniversaryYear, birth.month, anniversaryDay);
    var months =
        (today.year - anniversary.year) * 12 + today.month - anniversary.month;
    final currentMonthDay = _clampDay(today.year, today.month, birth.day);
    if (today.day < currentMonthDay) months--;

    final monthAnchor = _addMonths(anniversary, months, birth.day);
    final days = today.difference(monthAnchor).inDays;
    final category = _category(years, months, days);
    return ChildAge(
      years: years,
      months: months,
      days: days,
      category: category,
    );
  }

  static String categoryForAge(int ageYears) {
    if (ageYears < 0) return 'di_luar_rentang';
    if (ageYears < 1) return 'baby';
    if (ageYears < 2) return 'toddler';
    if (ageYears <= 5) return 'balita';
    return 'di_luar_rentang';
  }

  static int _compareMonthDay(DateTime first, DateTime second) {
    if (first.month != second.month) return first.month.compareTo(second.month);
    return first.day.compareTo(second.day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static int _clampDay(int year, int month, int day) =>
      day < _daysInMonth(year, month) ? day : _daysInMonth(year, month);

  static DateTime _addMonths(DateTime date, int months, int birthDay) {
    final monthIndex = date.year * 12 + date.month - 1 + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    return DateTime(year, month, _clampDay(year, month, birthDay));
  }

  static String _category(int years, int months, int days) {
    if (years < 1) return 'baby';
    if (years < 2) return 'toddler';
    if (years < 5 || (years == 5 && months == 0 && days == 0)) {
      return 'balita';
    }
    return 'di_luar_rentang';
  }
}
