import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminActionMenu extends StatelessWidget {
  final DocumentSnapshot document;

  const AdminActionMenu({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white,
      ),

      color: const Color(0xff1E293B),

      onSelected: (value) async {

        switch (value) {

          case "approve":
            await document.reference.update({
              "status": "approved",
            });
            break;

          case "pending":
            await document.reference.update({
              "status": "pending",
            });
            break;

          case "reject":
            await document.reference.update({
              "status": "rejected",
            });
            break;

            case "available":
  await document.reference.update({
    "availabilityStatus": "متوفر",
  });
  break;

case "reserved":
  await document.reference.update({
    "availabilityStatus": "محجوز",
  });
  break;

case "sold":
  await document.reference.update({
    "availabilityStatus": "تم البيع",
  });
  break;

case "rented":
  await document.reference.update({
    "availabilityStatus": "مؤجر",
  });
  break;

case "unavailable":
  await document.reference.update({
    "availabilityStatus": "غير متوفر",
  });
  break;

          case "delete":
            await document.reference.delete();
            break;
        }
        if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("تم تنفيذ العملية بنجاح"),
    ),
  );
}
      },

      itemBuilder: (context) => [
                const PopupMenuItem(
          value: "approve",
          child: ListTile(
            leading: Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            title: Text("قبول الإعلان"),
          ),
        ),

        const PopupMenuItem(
          value: "pending",
          child: ListTile(
            leading: Icon(
              Icons.hourglass_empty,
              color: Colors.orange,
            ),
            title: Text("إرجاع للمراجعة"),
          ),
        ),

        const PopupMenuItem(
          value: "reject",
          child: ListTile(
            leading: Icon(
              Icons.cancel,
              color: Colors.red,
            ),
            title: Text("رفض الإعلان"),
          ),
        ),

        const PopupMenuDivider(),

        const PopupMenuItem(
          value: "available",
          child: ListTile(
            leading: Icon(
              Icons.home,
              color: Colors.green,
            ),
            title: Text("متوفر"),
          ),
        ),

        const PopupMenuItem(
          value: "reserved",
          child: ListTile(
            leading: Icon(
              Icons.lock_clock,
              color: Colors.orange,
            ),
            title: Text("محجوز"),
          ),
        ),

        const PopupMenuItem(
          value: "sold",
          child: ListTile(
            leading: Icon(
              Icons.sell,
              color: Colors.red,
            ),
            title: Text("تم البيع"),
          ),
        ),

        const PopupMenuItem(
          value: "rented",
          child: ListTile(
            leading: Icon(
              Icons.key,
              color: Colors.blue,
            ),
            title: Text("مؤجر"),
          ),
        ),

        const PopupMenuItem(
          value: "unavailable",
          child: ListTile(
            leading: Icon(
              Icons.block,
              color: Colors.grey,
            ),
            title: Text("غير متوفر"),
          ),
        ),

        const PopupMenuDivider(),

        const PopupMenuItem(
          value: "delete",
          child: ListTile(
            leading: Icon(
              Icons.delete,
              color: Colors.red,
            ),
            title: Text("حذف العقار"),
          ),
        ),
              ],
    );
  }
}