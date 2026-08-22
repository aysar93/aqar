class IraqiPhoneService {
  IraqiPhoneService._();

  static const Map<String, String> _localizedDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static String toEnglishDigits(String value) {
    return value.split('').map((character) {
      return _localizedDigits[character] ?? character;
    }).join();
  }

  static String? normalize(String value) {
    var digits = toEnglishDigits(value).replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00964')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('964')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (!RegExp(r'^7\d{9}$').hasMatch(digits)) return null;
    return '+964$digits';
  }

  static bool looksLikePhone(String value) {
    final normalized = toEnglishDigits(value).trim();
    return !normalized.contains('@') &&
        RegExp(r'^[+0-9\s()\-]+$').hasMatch(normalized);
  }

  static String localDisplay(String normalizedPhone) {
    final normalized = normalize(normalizedPhone);
    if (normalized == null) return normalizedPhone;
    return '0${normalized.substring(4)}';
  }
}
