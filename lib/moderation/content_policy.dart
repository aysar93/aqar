/// A fast text guard complements reporting and administrative review of public UGC.
/// It is intentionally not presented as an exhaustive semantic classifier.
class ContentPolicy {
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640\u200B-\u200F]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا');
  static bool rejects(String value) =>
      value.length > 10000 ||
      RegExp(
        r'porn|xxx|fuck|shit|اباحي|قحبة|شرموط|كس ام|كسم|نيك|اغتصاب',
      ).hasMatch(normalize(value));
  static void validate(String value) {
    if (rejects(value))
      throw ArgumentError(
          'يتضمن النص محتوى غير مسموح. يرجى تعديله قبل الإرسال.');
  }
}
