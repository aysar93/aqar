import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isClosed;
  final VoidCallback onBack;
  final VoidCallback? onSettings;

  const ChatAppBar({
    super.key,
    required this.isClosed,
    required this.onBack,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      elevation: 0,
      centerTitle: false,
      actions: [
        if (onSettings != null)
          IconButton(
            tooltip: 'إعدادات المحادثة',
            onPressed: onSettings,
            icon: const Icon(Icons.more_vert, color: Color(0xFFC5A16B)),
          )
      ],
      leading: IconButton(
        tooltip: "رجوع",
        onPressed: onBack,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFFC5A16B),
          size: 22,
        ),
      ),
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("settings")
            .doc("app_settings")
            .snapshots(),
        builder: (context, snapshot) {
          String officeName = "الإدارة";
          String logoUrl = "";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;

            officeName = data["officeName"] ?? officeName;

            logoUrl = data["logoUrl"] ?? "";
          }

          return Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFC5A16B),
                backgroundImage:
                    logoUrl.isNotEmpty ? CachedNetworkImageProvider(logoUrl) : null,
                child: logoUrl.isEmpty
                    ? const Icon(
                        Icons.support_agent,
                        color: Colors.black,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      officeName,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isClosed ? "المحادثة مغلقة" : "فريق خدمة العملاء",
                      style: TextStyle(
                        color: isClosed ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
