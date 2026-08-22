import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isClosed;
  final VoidCallback onBack;

  const ChatAppBar({
    super.key,
    required this.isClosed,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        tooltip: "رجوع",
        onPressed: onBack,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFFD4AF37),
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
                backgroundColor: const Color(0xFFD4AF37),
                backgroundImage:
                    logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isClosed ? "المحادثة مغلقة" : "متصل",
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
