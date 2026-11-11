import '../services/iraqi_phone_service.dart';

/// Shared form validation helpers for the booking system across Android & iOS.
class BookingFormValidator {
  BookingFormValidator._();

  static String? requiredText(
    String? raw, {
    required String fieldName,
    int minLength = 1,
    int maxLength = 500,
  }) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (trimmed.length < minLength) {
      return '$fieldName قصير جداً (الحد الأدنى $minLength أحرف)';
    }
    if (trimmed.length > maxLength) {
      return '$fieldName يتجاوز الطول المسموح ($maxLength حرف)';
    }
    return null;
  }

  /// Validates Iraqi local/international numbers or valid E.164 phones.
  /// Returns normalized E.164 phone string when valid, or null when invalid.
  static String? normalizeValidPhone(String? raw) {
    final trimmed = IraqiPhoneService.toEnglishDigits((raw ?? '').trim());
    if (trimmed.isEmpty || trimmed.length > 50) return null;
    if (RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(trimmed)) return null;

    final iraqi = IraqiPhoneService.normalize(trimmed);
    if (iraqi != null) return iraqi;

    final compact = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact)) {
      return compact;
    }
    return null;
  }

  static String? phoneError(String? raw, {bool required = true}) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return required ? 'يرجى إدخال رقم الهاتف للتواصل' : null;
    }
    if (normalizeValidPhone(trimmed) == null) {
      return 'أدخل رقم هاتف صحيح (مثال: 07XXXXXXXXX أو +9647XXXXXXXXX)';
    }
    return null;
  }

  static String? intRangeError(
    String? raw, {
    required String fieldName,
    required int min,
    required int max,
    bool required = true,
  }) {
    final trimmed = IraqiPhoneService.toEnglishDigits((raw ?? '').trim());
    if (trimmed.isEmpty) {
      return required ? 'يرجى إدخال $fieldName' : null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return 'يرجى إدخال رقم صحيح في حقل $fieldName';
    }
    if (parsed < min || parsed > max) {
      return 'قيمة $fieldName يجب أن تكون بين $min و $max';
    }
    return null;
  }
}
