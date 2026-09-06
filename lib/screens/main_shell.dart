import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'add_property/add_property_screen.dart';
import 'property_request/property_request_screen.dart';
import 'notifications_screen.dart';
import '../reels/screens/reels_screen.dart';

import '../chat/chat_screen.dart';

import '../widgets/navigation/custom_bottom_bar.dart';
import '../widgets/navigation/advertise_options_sheet.dart';

import '../services/fcm_service.dart';
import '../widgets/notification_permission_sheet.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int currentIndex;
  String _accountMode = 'user';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _accountModeSubscription;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex;
    _listenToAccountMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  // ==================================================
  // متابعة وضع الحساب الشخصي / وضع المكتب
  // ==================================================

  void _listenToAccountMode() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _accountMode = 'user';
      return;
    }

    _accountModeSubscription?.cancel();
    _accountModeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data() ?? {};
      final newMode = (data['accountMode'] ?? 'user').toString();
      final normalizedMode = newMode == 'office' ? 'office' : 'user';

      if (!mounted || normalizedMode == _accountMode) return;

      setState(() {
        _accountMode = normalizedMode;
      });
    });
  }

  @override
  void dispose() {
    _accountModeSubscription?.cancel();
    super.dispose();
  }

  // ==================================================
  // صلاحية الإشعارات
  // ==================================================

  Future<void> _checkNotificationPermission() async {
    // لا نعرض النافذة للضيف
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // تحقق من صلاحية الإشعارات الحالية
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    final isAllowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    // إذا كانت الإشعارات مفعلة أصلًا
    // نحفظ Tokens فقط ولا نعرض أي نافذة
    if (isAllowed) {
      await FCMService.saveTokens();
      return;
    }

    // تحقق هل المستخدم ضغط "ليس الآن" سابقًا
    final prefs = await SharedPreferences.getInstance();

    final postponed =
        prefs.getBool('notification_permission_postponed') ?? false;

    if (postponed) {
      return;
    }

    if (!mounted) {
      return;
    }

    // عرض نافذة طلب صلاحية الإشعارات
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return NotificationPermissionSheet(
          onEnable: () async {
            Navigator.pop(sheetContext);

            final allowed = await FCMService.requestNotificationPermission();

            if (allowed) {
              // إذا وافق المستخدم نحذف حالة التأجيل
              await prefs.remove(
                'notification_permission_postponed',
              );
            }
          },
          onLater: () async {
            // لا نعيد عرض النافذة في كل تشغيل
            await prefs.setBool(
              'notification_permission_postponed',
              true,
            );

            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
        );
      },
    );
  }

  // ==================================================
  // الرجوع من المحادثة إلى الرئيسية
  // ==================================================

  void _backToHome() {
    if (currentIndex == 0) {
      return;
    }

    setState(() {
      currentIndex = 0;
    });
  }

  // ==================================================
  // صفحات الشريط السفلي
  // ==================================================

  List<Widget> get pages => [
        HomeScreen(key: ValueKey('home-$_accountMode')),
        const ReelsScreen(),
        FavoritesScreen(
          onExplore: () {
            if (!mounted) return;

            setState(() {
              currentIndex = 0;
            });
          },
        ),
        const SizedBox(),
        const NotificationsScreen(),
        ChatScreen(
          onBack: _backToHome,
        ),
      ];

  // ==================================================
  // فتح تسجيل الدخول
  // ==================================================

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  // ==================================================
  // اعرض عقارًا
  // ==================================================

  void _openAddProperty() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _openLogin();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPropertyScreen(),
      ),
    );
  }

  // ==================================================
  // اطلب عقارًا
  // ==================================================

  void _openPropertyRequest() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _openLogin();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PropertyRequestScreen(),
      ),
    );
  }

  // ==================================================
  // نافذة أعلن
  // ==================================================

  Future<void> _openAdvertiseOptions() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return AdvertiseOptionsSheet(
          // ==========================================
          // اعرض عقارًا
          // ==========================================

          onOfferProperty: () {
            Navigator.pop(sheetContext);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              _openAddProperty();
            });
          },

          // ==========================================
          // اطلب عقارًا
          // ==========================================

          onRequestProperty: () {
            Navigator.pop(sheetContext);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              _openPropertyRequest();
            });
          },
        );
      },
    );
  }

  Future<void> _handleBottomNavigation(int index) async {
    // ==========================================
    // المحادثة تحتاج تسجيل الدخول
    // ==========================================
    if (index == 5) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFFD4AF37),
                  width: 1,
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFD4AF37),
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "تسجيل الدخول مطلوب",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                "للتواصل مع الإدارة عبر المحادثة، يرجى تسجيل الدخول إلى حسابك أولاً",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }

                      _openLogin();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.login_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    "تسجيل الدخول",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        return;
      }
    }

    // ==========================================
    // باقي صفحات الشريط السفلي
    // ==========================================
    if (!mounted) {
      return;
    }

    setState(() {
      currentIndex = index;
    });
  }

  // ==================================================
  // الواجهة
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final bool hideBottomBar = currentIndex == 5;

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: hideBottomBar
          ? null
          : CustomBottomBar(
              currentIndex: currentIndex,
              onTap: _handleBottomNavigation,
              onAddTap: _openAdvertiseOptions,
            ),
    );
  }
}
