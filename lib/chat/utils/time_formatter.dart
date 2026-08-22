import 'package:intl/intl.dart';

class TimeFormatter {
  static String format(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return "الآن";
    }

    if (difference.inMinutes < 60) {
      return "قبل ${difference.inMinutes} دقيقة";
    }

    if (difference.inHours < 24 &&
        now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return "قبل ${difference.inHours} ساعة";
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return "أمس";
    }

    return DateFormat("dd/MM/yyyy").format(date);
  }
}
