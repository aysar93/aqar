import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChangeAvailabilitySheet extends StatelessWidget {
  final String documentId;
  final String currentStatus;

  const ChangeAvailabilitySheet({
    super.key,
    required this.documentId,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = {
      "available": "متاح",
      "reserved": "محجوز",
      "sold": "مباع",
      "rented": "مؤجر",
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "حالة العقار",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...statuses.entries.map(
              (item) => ListTile(
                leading: Icon(
                  item.key == currentStatus
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xffD4AF37),
                ),
                title: Text(item.value),
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection("properties")
                      .doc(documentId)
                      .update({
                    "availabilityStatus": item.key,
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
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
