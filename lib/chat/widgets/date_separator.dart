import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    final messageDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    String text;

    if (messageDate == today) {
      text = "اليوم";
    } else if (messageDate == yesterday) {
      text = "أمس";
    } else {
      text = DateFormat(
        "dd/MM/yyyy",
      ).format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: Colors.white24,
            ),
          ),

          Container(
            margin:
                const EdgeInsets.symmetric(
              horizontal: 10,
            ),

            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 5,
            ),

            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius:
                  BorderRadius.circular(20),
            ),

            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Expanded(
            child: Divider(
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}