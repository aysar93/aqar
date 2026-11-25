import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangeAvailabilitySheet extends StatelessWidget {
  final String documentId;
  final String currentStatus;
  final String? ownerId;

  const ChangeAvailabilitySheet({
    super.key,
    required this.documentId,
    required this.currentStatus,
    this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final statuses = {
      "available": "متوفر",
      "reserved": "محجوز",
      "sold": "تم البيع",
      "rented": "تم التأجير",
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "حالة توفر العقار",
              style: TextStyle(
                color: onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...statuses.entries.map(
              (item) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  item.key == currentStatus
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xffC5A16B),
                ),
                title: Text(
                  item.value,
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: item.key == currentStatus
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (ownerId != null &&
                      currentUser != null &&
                      currentUser.uid != ownerId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('غير مصرح لك بتغيير حالة هذا العقار'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection("properties")
                        .doc(documentId)
                        .update({
                      "availabilityStatus": item.key,
                      "updatedAt": FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('تم تحديث حالة التوفر إلى: ${item.value}'),
                          backgroundColor: const Color(0xff1E293B),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تعذر تحديث الحالة: $e'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
