import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final int notificationCount;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationPressed;

  const HomeHeader({
    super.key,
    required this.userName,
    this.photoUrl,
    required this.notificationCount,
    required this.onMenuPressed,
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          InkWell(
            onTap: onMenuPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xff1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xffD4AF37),
              ),
            ),
          ),

          const SizedBox(width: 14),

          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xffD4AF37),
            backgroundImage: (photoUrl != null &&
                    photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? const Icon(
                    Icons.person,
                    color: Colors.black,
                  )
                : null,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "مرحباً بك",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Stack(
            children: [
              InkWell(
                onTap: onNotificationPressed,
                borderRadius:
                    BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xff1E293B),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                  ),
                ),
              ),

              if (notificationCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notificationCount > 9
                          ? "9+"
                          : notificationCount
                              .toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}