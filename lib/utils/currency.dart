import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String iqd(dynamic amount) {
  num number = 0;

  if (amount is num) {
    number = amount;
  } else if (amount is String) {
    number = double.tryParse(
          amount.replaceAll('د.ع', '').replaceAll(',', '').trim(),
        ) ??
        0;
  }

  return '${NumberFormat('#,###').format(number)} د.ع';
}

String amountToArabicWords(String amount) {
  final number = amount.replaceAll(',', '').trim();

  if (number.isEmpty) {
    return "";
  }

  return "$number دينار عراقي";
}

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat formatter = NumberFormat("#,###");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // تحويل الأرقام العربية إلى الإنجليزية
    text = text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    text = text.replaceAll(',', '');

    if (text.isEmpty) {
      return const TextEditingValue();
    }

    final number = int.tryParse(text);

    if (number == null) {
      return oldValue;
    }

    final formatted = formatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}
