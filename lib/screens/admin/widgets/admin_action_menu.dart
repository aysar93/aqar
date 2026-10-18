import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'change_availability_sheet.dart';
import '../../../services/notification_service.dart';

class AdminActionMenu extends StatelessWidget {
  final DocumentSnapshot document;

  const AdminActionMenu({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>;

    final isFeatured = data["isFeatured"] ?? false;

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      color: const Color(0xff1E293B),
      onSelected: (value) async {
        switch (value) {
          case "availability":
            if (!context.mounted) return;

            final currentStatus =
                data["availabilityStatus"]?.toString() ?? "available";

            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xff1E293B),
              isScrollControlled: true,
              builder: (_) => ChangeAvailabilitySheet(
                documentId: document.id,
                currentStatus: currentStatus,
              ),
            );
            return;

          case "approve":
            await document.reference.update({
              "status": "approved",
            });

            final ownerUid =
                (data["publisherUid"] ?? data["userId"] ?? "").toString();

            if (ownerUid.isNotEmpty) {
              await NotificationService.sendNotification(
                title: "تم قبول إعلانك",
                message: "تمت الموافقة على عقارك بنجاح",
                type: "property_approved",
                target: "user",
                userId: ownerUid,
                propertyId: document.id,
              );
            } else {
              debugPrint(
                "AdminActionMenu: "
                "Cannot send approval notification - owner UID is empty. "
                "propertyId=${document.id}",
              );
            }

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

            final ownerUid =
                (data["publisherUid"] ?? data["userId"] ?? "").toString();

            if (ownerUid.isNotEmpty) {
              await NotificationService.sendNotification(
                title: "تم رفض إعلانك",
                message: "تم رفض العقار من قبل الإدارة، يرجى مراجعة البيانات",
                type: "property_rejected",
                target: "user",
                userId: ownerUid,
                propertyId: document.id,
              );
            } else {
              debugPrint(
                "AdminActionMenu: "
                "Cannot send rejection notification - owner UID is empty. "
                "propertyId=${document.id}",
              );
            }

            break;

          case "featured":
            await document.reference.update({
              "isFeatured": !isFeatured,
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
          value: "availability",
          child: ListTile(
            leading: Icon(
              Icons.check_circle_outline,
              color: Colors.green,
            ),
            title: Text("تغيير حالة التوفر"),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: "featured",
          child: ListTile(
            leading: Icon(
              isFeatured ? Icons.star : Icons.star_border,
              color: const Color(0xffD4AF37),
            ),
            title: Text(
              isFeatured ? "إلغاء تمييز العقار" : "تمييز العقار",
            ),
            contentPadding: EdgeInsets.zero,
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
