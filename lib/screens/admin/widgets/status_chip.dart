import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool availability;

  const StatusChip({
    super.key,
    required this.status,
    this.availability = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text = status;

    if (availability) {
      switch (status) {
        case "متوفر":
          color = Colors.green;
          icon = Icons.check_circle;
          break;

        case "محجوز":
          color = Colors.orange;
          icon = Icons.lock_clock;
          break;

        case "تم البيع":
          color = Colors.red;
          icon = Icons.sell;
          break;

        case "مؤجر":
          color = Colors.blue;
          icon = Icons.key;
          break;

        case "غير متوفر":
          color = Colors.grey;
          icon = Icons.block;
          break;

        default:
          color = Colors.grey;
          icon = Icons.help;
      }
    } else {
      switch (status) {
        case "approved":
          color = Colors.green;
          icon = Icons.verified;
          text = "مقبول";
          break;

        case "pending":
          color = Colors.orange;
          icon = Icons.schedule;
          text = "قيد المراجعة";
          break;

        case "rejected":
          color = Colors.red;
          icon = Icons.cancel;
          text = "مرفوض";
          break;

        default:
          color = Colors.grey;
          icon = Icons.help;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: color.withValues(alpha: .35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
