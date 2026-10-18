/// Complete Arabic substring matching; independent of cursor-loaded pages.
abstract final class PropertyTextSearch {
  /// يوحّد النص العربي حتى لا تمنع اختلافات الكتابة ظهور النتيجة.
  /// مثال: "للإيجار" و"للايجار"، والأرقام العربية والإنجليزية.
  static String normalize(Object? value) {
    var text = (value ?? '').toString().toLowerCase().trim();

    const replacements = <String, String>{
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ٱ': 'ا',
      'ى': 'ي',
      'ؤ': 'و',
      'ئ': 'ي',
      'ة': 'ه',
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

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    // حذف التشكيل والتطويل، وتحويل الرموز والفواصل إلى مسافات.
    text = text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  static String searchableText(
    String documentId,
    Map<String, dynamic> data,
  ) {
    const searchableFields = <String>[
      'title',
      'location',
      'city',
      'governorate',
      'district',
      'areaName',
      'neighborhood',
      'landmark',
      'propertyType',
      'adType',
      'description',
      'adNumber',
      'propertyNumber',
      'propertyNo',
      'price',
      'area',
      'rooms',
      'bathrooms',
      'frontage',
      'depth',
      'buildYear',
      'documentType',
      'furnitureStatus',
      'publisherName',
      'officeName',
      'features',
    ];

    final values = <Object?>[documentId];
    for (final field in searchableFields) {
      final value = data[field];
      if (value is Iterable) {
        values.addAll(value);
      } else {
        values.add(value);
      }
    }

    return normalize(values.join(' '));
  }

  static bool matches(
    String query,
    String documentId,
    Map<String, dynamic> data,
  ) {
    final normalizedQuery = normalize(query.replaceAll('#', ' '));
    if (normalizedQuery.isEmpty) return true;

    final haystack = searchableText(documentId, data);
    final words =
        normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();

    // كل كلمة يمكن أن توجد في حقل مختلف؛ مثل "بيت للبيع الحوز 200".
    return words.every(haystack.contains);
  }
}
