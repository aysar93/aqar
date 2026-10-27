import '../screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_widgets.dart';
import 'booking_extras.dart';
import 'booking_management.dart';
import 'booking_map.dart';
import 'booking_my_venues_screen.dart';
import 'booking_screen.dart';
import 'booking_workspace.dart';

/// My Account screen for the Bookings ecosystem («حسابي»).
/// Inspired by luxury modern profile screens with a curved header,
/// 3-stat overview (Reviews, Favorites, Bookings), owner callout,
/// sleek option rows, and owner pending requests badge.
/// Strictly excludes Logout and Account Deletion (managed by main app).
class BookingAccountScreen extends StatefulWidget {
  final bool admin;
  final VoidCallback? onOpenAdminTools;
  final bool embedded;

  const BookingAccountScreen({
    super.key,
    this.admin = false,
    this.onOpenAdminTools,
    this.embedded = false,
  });

  @override
  State<BookingAccountScreen> createState() => _BookingAccountScreenState();
}

class _BookingAccountScreenState extends State<BookingAccountScreen> {
  bool _canReviewFinance = false;

  User? get _currentUser =>
      Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;

  @override
  void initState() {
    super.initState();
    _checkFinanceRole();
  }

  Future<void> _checkFinanceRole() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
        if (mounted && doc.exists) {
          setState(() {
            _canReviewFinance = doc.data()?['canReviewBookingPayments'] == true;
          });
        }
      }
    } catch (_) {}
  }

  void _showVenueUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: bookingGold),
              SizedBox(width: 8),
              Text('المكان غير متاح حالياً',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'عذراً، هذا المكان لم يعد متوفراً في النظام أو تم حذفه من قِبل المالك.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = _currentUser;
    final uid = user?.uid;

    final bodyContent = SingleChildScrollView(
      child: Column(
        children: [
          // 1. Curved Header behind User Info
          _buildCurvedHeader(context, isDark, user),

          // 2. 3-Section Stats Card (Floating/overlapping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: _buildStatsCard(context, isDark, uid),
            ),
          ),

          // Content below stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 3. Owner Callout Card
                _buildOwnerCallout(context, isDark),

                const SizedBox(height: 14),

                // 4. Favorites Rose/Gold Card
                _buildFavoritesCard(context, isDark),

                const SizedBox(height: 18),

                // 5. Sleek Options List
                _buildOptionsSection(context, isDark, uid),

                const SizedBox(height: 28),

                Center(
                  child: Text(
                    'عقارات الأنبار · نظام الحجوزات والشاليهات',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: bodyContent,
    );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: content);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: bodyContent,
      ),
    );
  }

  /// 1. Curved Header
  Widget _buildCurvedHeader(BuildContext context, bool isDark, User? user) {
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'مستخدم عقارات الأنبار';
    final phone = user?.phoneNumber?.trim().isNotEmpty == true
        ? user!.phoneNumber!
        : (user?.email?.trim().isNotEmpty == true ? user!.email! : 'حساب نشط');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 14,
        bottom: 50,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0B192C), Color(0xFF1E3E62)]
              : const [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Screen Title
          const Text(
            'حسابي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 18),

          // Centered Avatar with Edit Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2.8,
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFC5A16B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (displayName.isNotEmpty ? displayName[0] : 'ع').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Centered Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 3),

          // Centered Phone / Info
          Text(
            phone,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  /// 2. 3-Section Stats Card (تقييماتي، المفضلة، حجوزاتي)
  Widget _buildStatsCard(BuildContext context, bool isDark, String? uid) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Column 1: تقييماتي
            Expanded(
              child: _buildSingleStat(
                context: context,
                icon: Icons.star_border_rounded,
                countStream: uid != null
                    ? FirebaseFirestore.instance
                        .collection('booking_reviews')
                        .where('userId', isEqualTo: uid)
                        .snapshots()
                    : null,
                label: 'تقييماتي',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('التقييمات تظهر بعد إتمام زياراتك للشاليهات'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),

            VerticalDivider(color: dividerColor, thickness: 1.5, indent: 6, endIndent: 6),

            // Column 2: المفضلة
            Expanded(
              child: _buildSingleStat(
                context: context,
                icon: Icons.favorite_border_rounded,
                countStream: uid != null
                    ? FirebaseFirestore.instance
                        .collection('users/$uid/saved_booking_reels')
                        .snapshots()
                    : null,
                label: 'المفضلة',
                onTap: () => _showSavedReelsSheet(context),
              ),
            ),

            VerticalDivider(color: dividerColor, thickness: 1.5, indent: 6, endIndent: 6),

            // Column 3: حجوزاتي
            Expanded(
              child: _buildSingleStat(
                context: context,
                icon: Icons.calendar_today_outlined,
                countStream: uid != null
                    ? FirebaseFirestore.instance
                        .collection('bookings')
                        .where('customerId', isEqualTo: uid)
                        .snapshots()
                    : null,
                label: 'حجوزاتي',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingScreen(initialTab: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStat({
    required BuildContext context,
    required IconData icon,
    required Stream<QuerySnapshot>? countStream,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(height: 4),
            countStream == null
                ? Text('0',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor))
                : StreamBuilder<QuerySnapshot>(
                    stream: countStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Owner Callout Card
  Widget _buildOwnerCallout(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.holiday_village_outlined,
              color: Color(0xFF1E3A8A),
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'هل تريد تأجير شاليهك أو عقارك؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'أضف شاليهك، حدّد الأسعار، واستقبل طلبات الحجز بسهولة وأمان.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddVenueModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
              label: const Text(
                'أضف مكانك الآن',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Favorites Rose/Pink Card
  Widget _buildFavoritesCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _showSavedReelsSheet(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            const Spacer(),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'المفضلة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الشاليهات والمقاطع التي حفظتها',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  /// 5. Sleek Options List (Image 1 style)
  Widget _buildOptionsSection(BuildContext context, bool isDark, String? uid) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. الإشعارات
          _buildOptionTile(
            context: context,
            icon: Icons.notifications_none_rounded,
            iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.12),
            iconColor: const Color(0xFF2563EB),
            title: 'الإشعارات والتنبيهات',
            subtitle: 'تنبيهات الحجوزات وموافقات الدفع',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _buildDivider(borderColor),

          // 2. إدارة أماكني وأسعاري (with pending requests counter badge)
          StreamBuilder<QuerySnapshot>(
            stream: uid != null
                ? FirebaseFirestore.instance
                    .collection('bookings')
                    .where('ownerId', isEqualTo: uid)
                    .where('status', isEqualTo: 'requested')
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.docs.length ?? 0;
              return _buildOptionTile(
                context: context,
                icon: Icons.storefront_outlined,
                iconBg: const Color(0xFFC5A16B).withValues(alpha: 0.15),
                iconColor: const Color(0xFFC5A16B),
                title: 'إدارة أماكني وأسعاري',
                subtitle: 'الشاليهات، الأسعار، التوفر والطلبات',
                badgeCount: pendingCount,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingMyVenuesScreen(userId: uid),
                    ),
                  );
                },
              );
            },
          ),
          _buildDivider(borderColor),

          // 3. خريطة الأماكن والشاليهات
          _buildOptionTile(
            context: context,
            icon: Icons.map_outlined,
            iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
            iconColor: const Color(0xFF059669),
            title: 'خريطة الأماكن والشاليهات',
            subtitle: 'استعراض جغرافي للأماكن والمسارات',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingMapScreen()),
              );
            },
          ),
          _buildDivider(borderColor),

          // 4. شروط وضوابط الحجز
          _buildOptionTile(
            context: context,
            icon: Icons.verified_user_outlined,
            iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            iconColor: const Color(0xFF7C3AED),
            title: 'شروط وسياسات الحجز',
            subtitle: 'سياسة العربون، الإلغاء، وتعليمات الدخول',
            onTap: () => _showPoliciesDialog(context),
          ),
          _buildDivider(borderColor),

          // 5. الدعم والمساعدة
          _buildOptionTile(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: const Color(0xFF06B6D4).withValues(alpha: 0.12),
            iconColor: const Color(0xFF0891B2),
            title: 'الدعم والمساعدة',
            subtitle: 'فريق المساعدة وخدمة العملاء',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingSupportScreen(admin: widget.admin),
                ),
              );
            },
          ),
          _buildDivider(borderColor),

          // 6. عن التطبيق
          _buildOptionTile(
            context: context,
            icon: Icons.info_outline_rounded,
            iconBg: const Color(0xFF64748B).withValues(alpha: 0.12),
            iconColor: const Color(0xFF475569),
            title: 'عن نظام الحجوزات',
            subtitle: 'الإصدار والشروط القانونية ومعلومات النظام',
            onTap: () => _showAboutDialog(context),
          ),

          // 7. أدوات الإدارة والمالية إذا كان لديه صلاحية
          if (widget.admin || _canReviewFinance) ...[
            _buildDivider(borderColor),
            if (_canReviewFinance || widget.admin)
              _buildOptionTile(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
                iconColor: const Color(0xFF10B981),
                title: 'المراجعة المالية وسجل العمليات',
                subtitle: 'وصولات الدفع وتأكيد الحجوزات',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingLedgerScreen(),
                    ),
                  );
                },
              ),
            if (widget.admin) ...[
              _buildDivider(borderColor),
              _buildOptionTile(
                context: context,
                icon: Icons.admin_panel_settings_outlined,
                iconBg: const Color(0xFFEF4444).withValues(alpha: 0.12),
                iconColor: const Color(0xFFDC2626),
                title: 'أدوات الإدارة الشاملة',
                subtitle: 'توثيق الملكية ومراجعة الوسائط والتقييمات',
                onTap: () {
                  if (widget.onOpenAdminTools != null) {
                    widget.onOpenAdminTools!();
                  } else {
                    _showAdminShortcuts(context);
                  }
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Divider(
      height: 1,
      thickness: 1,
      color: borderColor.withValues(alpha: 0.7),
      indent: 64,
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Rounded Icon Square
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount طلب',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Chevron
            Icon(
              Icons.chevron_left_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVenueModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'اختر نوع المكان لإضافته',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اختر التصنيف الأنسب لمكانك لإكمال نموذج البيانات وإرفاق الصور وثائق الملكية.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildCategoryOption(
                      ctx,
                      title: 'شاليه',
                      category: 'chalet',
                      icon: Icons.pool_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryOption(
                      ctx,
                      title: 'مزرعة',
                      category: 'farm',
                      icon: Icons.nature_people_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryOption(
                      ctx,
                      title: 'قاعة',
                      category: 'hall',
                      icon: Icons.celebration_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryOption(
                      ctx,
                      title: 'استراحة',
                      category: 'other',
                      icon: Icons.holiday_village_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryOption(
    BuildContext ctx, {
    required String title,
    required String category,
    required IconData icon,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          final uid = _currentUser?.uid;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingVenueEditor(
                ownerMode: true,
                data: {
                  'ownerId': uid,
                  'category': category,
                  'active': false,
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bookingGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bookingGold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: bookingGold, size: 28),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedReelsSheet(BuildContext context) {
    final uid = _currentUser?.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المحفوظات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: uid == null
                      ? const Center(
                          child: Text('سجل الدخول لعرض المحفوظات', style: TextStyle(fontFamily: 'Cairo')),
                        )
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users/$uid/saved_booking_reels')
                              .orderBy('savedAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: bookingGold));
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'لا توجد مقاطع محفوظة بعد\nيمكنك حفظ أي ريلز بالضغط على أيقونة الإشارة المرجعية',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final data = docs[idx].data();
                                return ListTile(
                                  onTap: () async {
                                    final venueId = data['venueId']?.toString();
                                    if (venueId == null || venueId.isEmpty) {
                                      _showVenueUnavailableDialog(context);
                                      return;
                                    }
                                    try {
                                      final doc = await FirebaseFirestore.instance
                                          .collection('booking_venues')
                                          .doc(venueId)
                                          .get();
                                      if (!doc.exists || doc.data() == null) {
                                        if (context.mounted) _showVenueUnavailableDialog(context);
                                        return;
                                      }
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BookingRequestScreen(
                                              venueId: venueId,
                                              venue: {'id': venueId, ...doc.data()!},
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) _showVenueUnavailableDialog(context);
                                    }
                                  },
                                  leading: const Icon(Icons.video_library_rounded, color: bookingGold),
                                  title: Text(
                                    data['venueName'] ?? 'مكان ترفيهي',
                                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    data['location'] ?? 'الأنبار',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => docs[idx].reference.delete(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPoliciesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'سياسات وضوابط الحجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1. العربون المركزي وتثبيت الحجز:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: bookingGold, fontFamily: 'Cairo'),
                ),
                Text(
                  'يتم حجز الموعد مؤقتاً لمدة ساعتين عند موافقة المالك. يجب تحويل العربون ورفع الوصل لتأكيد الحجز نهائياً.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, fontFamily: 'Cairo'),
                ),
                SizedBox(height: 10),
                Text(
                  '2. سياسة الإلغاء والاسترجاع:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: bookingGold, fontFamily: 'Cairo'),
                ),
                Text(
                  'يمكن إلغاء الحجز مجاناً حتى 48 ساعة قبل الموعد. في حال الإلغاء المتأخر يخضع العربون لسياسة المكان المعتمدة.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, fontFamily: 'Cairo'),
                ),
                SizedBox(height: 10),
                Text(
                  '3. الحفاظ على الممتلكات ومواعيد الدخول:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: bookingGold, fontFamily: 'Cairo'),
                ),
                Text(
                  'يلتزم المستأجر بالمحافظة على نظافة المكان ومرافقه ومواعيد تسجيل الدخول والخروج عبر رمز الدخول الذكي QR.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: bookingGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً فهمت', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: bookingGold),
              SizedBox(width: 8),
              Text(
                'عن نظام الحجوزات',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'نظام حجوزات الشاليهات والقاعات والمزارع في محافظة الأنبار، صُمم لتوفير تجربة حجز رقمية آمنة وموثوقة مع ضمان العربون المركزي وإدارة أوقات الدخول والخروج الذكية.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminShortcuts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'أدوات مشرف الحجوزات',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    BookingWorkspaceAction(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookingProofInbox()),
                        );
                      },
                      child: const Text('توثيق الملكية'),
                    ),
                    BookingWorkspaceAction(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookingMediaInbox()),
                        );
                      },
                      child: const Text('مراجعة الوسائط'),
                    ),
                    BookingWorkspaceAction(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookingReviewInbox()),
                        );
                      },
                      child: const Text('مراجعة التقييمات'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
