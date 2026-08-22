import 'package:flutter/material.dart';
import '../../core/design/aqar_sizes.dart';
import '../../core/design/aqar_spacing.dart';
import '../../core/design/aqar_text.dart';

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

  static const Color _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AqarSpacing.screen(context),
        AqarSpacing.sm(context),
        AqarSpacing.screen(context),
        AqarSpacing.md(context),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // زر القائمة
          _squareButton(
            context,
            icon: Icons.menu_rounded,
            color: _gold,
            onTap: onMenuPressed,
          ),

          SizedBox(width: AqarSpacing.sm(context)),

          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xffF2C94C),
                  Color(0xffD4AF37),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xffD4AF37),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: AqarSizes.avatarRadius(context),
              backgroundColor: _gold,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Icon(
                      Icons.person,
                      color: Colors.black,
                      size: AqarSizes.avatarIcon(context),
                    )
                  : null,
            ),
          ),

          SizedBox(width: AqarSpacing.sm(context)),

          Expanded(
            child: userName == "مستخدم"
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "مرحباً بك يا ضيف",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AqarText.pageTitle(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "مرحباً بك",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: AqarText.small(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),

          SizedBox(width: AqarSpacing.sm(context)),

          Stack(
            clipBehavior: Clip.none,
            children: [
              _squareButton(
                context,
                icon: Icons.notifications_none_rounded,
                color: Colors.white,
                onTap: onNotificationPressed,
              ),
              if (notificationCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xff0F172A),
                        width: 2.5,
                      ),
                    ),
                    child: Text(
                      notificationCount > 9 ? "9+" : "$notificationCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
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

  Widget _squareButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0x33D4AF37),
        highlightColor: const Color(0x11D4AF37),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: AqarSizes.headerButton(context),
          height: AqarSizes.headerButton(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff263548),
                Color(0xff1E293B),
              ],
            ),
            border: Border.all(
              color: const Color(0x35D4AF37),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: AqarSizes.headerIcon(context),
            ),
          ),
        ),
      ),
    );
  }
}
