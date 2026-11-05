class InputValidationService {
  InputValidationService._();

  static final _personNamePattern = RegExp(
    // Antar kata boleh spasi, apostrof, tanda hubung, atau titik (boleh diikuti spasi, mis. "M. Rizky").
    // Sama dengan aturan di server (src/services/validators.js).
    r"^[\p{L}\p{M}]+(?:(?:\. ?|[ '’\-])[\p{L}\p{M}]+)*$",
    unicode: true,
  );

  static final _decimalPattern = RegExp(r'^\d+(?:[.,]\d{1,2})?$');
  static final _integerPattern = RegExp(r'^\d+$');
  static final _phonePattern = RegExp(r'^\+?[0-9 ()-]{8,24}$');

  static bool isNumericOnly(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && RegExp(r'^\d+$').hasMatch(trimmed);
  }

  static bool isValidName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length >= 2 &&
        normalized.length <= 80 &&
        _personNamePattern.hasMatch(normalized);
  }

  static bool isValidNumber(
    String value, {
    required double minimum,
    required double maximum,
  }) {
    final normalized = value.trim();
    if (!_decimalPattern.hasMatch(normalized)) return false;
    final number = double.tryParse(normalized.replaceAll(',', '.'));
    return number != null &&
        number.isFinite &&
        number >= minimum &&
        number <= maximum;
  }

  static bool isValidInteger(
    String value, {
    required int minimum,
    required int maximum,
  }) {
    final normalized = value.trim();
    if (!_integerPattern.hasMatch(normalized)) return false;
    final number = int.tryParse(normalized);
    return number != null && number >= minimum && number <= maximum;
  }

  static bool isValidPhone(String value) {
    final normalized = value.trim();
    if (!_phonePattern.hasMatch(normalized)) return false;
    final digitCount = normalized.replaceAll(RegExp(r'\D'), '').length;
    return digitCount >= 8 && digitCount <= 15;
  }
}
