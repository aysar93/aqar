import 'package:flutter/material.dart';

/// الهوية البصرية الموحدة ونظام التصميم للوحة إدارة الحجوزات — عقارات الأنبار (SaaS Admin Design System)
class BookingAdminTheme {
  // الألوان الثابتة (الوضع الداكن الافتراضي) — مطابقة تامة للاختبارات الحالية
  static const Color bgPrimary = Color(0xFF0F172A); // كحلي داكن
  static const Color surfaceCard = Color(0xFF1E293B); // كحلي هادئ للبطاقات
  static const Color surfaceAlt = Color(0xFF162238); // كحلي بديل ثانوي
  static const Color surfaceHeader = Color(0xFF111C33); // شريط علوي وقوائم
  static const Color surfaceHover = Color(0xFF24344D); // عند التمرير/التركيز
  static const Color borderSubtle = Color(0xFF334155); // رمادي مزرق خافت للحدود
  static const Color borderLight = Color(0x1FFFFFFF); // حد شفاف خفيف

  // ألوان التأكيد (تستخدم باعتدال)
  static const Color gold = Color(0xFFD4AF37); // ذهبي خافت معتمد
  static const Color goldSubtle = Color(0x26D4AF37); // ذهبي شفاف للخلفيات النشطة
  static const Color goldHover = Color(0xFFE5C158); // ذهبي عند التفاعل

  // النصوص (الوضع الداكن)
  static const Color textPrimary = Color(0xFFF8FAFC); // أبيض مائل للرمادي
  static const Color textSecondary = Color(0xFFE2E8F0); // فضي واضح
  static const Color textMuted = Color(0xFF94A3B8); // رمادي مزرق خافت للمعلومات الثانوية

  // الأيقونات: موحدة باللون الأبيض المائي أو الفضي (ممنوع الأيقونات الملونة العشوائية)
  static const Color iconColor = Color(0xFFE2E8F0);
  static const Color iconMuted = Color(0xFF94A3B8);

  // شارات الحالة (Status Badges) — استخدام هادئ ومدروس وظيفياً
  static const Color badgeConfirmedBg = Color(0x1F22C55E);
  static const Color badgeConfirmedText = Color(0xFF4ADE80);

  static const Color badgePendingBg = Color(0x1FEAB308);
  static const Color badgePendingText = Color(0xFFFDE047);

  static const Color badgeReviewBg = Color(0x1F38BDF8);
  static const Color badgeReviewText = Color(0xFF7DD3FC);

  static const Color badgeCancelledBg = Color(0x1FEF4444);
  static const Color badgeCancelledText = Color(0xFFFCA5A5);

  static const Color badgeNeutralBg = Color(0x1F94A3B8);
  static const Color badgeNeutralText = Color(0xFFCBD5E1);

  // دعم الألوان المتكيفة مع الوضعين الفاتح والداكن (Adaptive SaaS Colors)
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) => isDark(context) ? bgPrimary : const Color(0xFFF8FAFC);
  static Color surface(BuildContext context) => isDark(context) ? surfaceCard : Colors.white;
  static Color surfaceSecondary(BuildContext context) => isDark(context) ? surfaceAlt : const Color(0xFFF1F5F9);
  static Color header(BuildContext context) => isDark(context) ? surfaceHeader : Colors.white;
  static Color border(BuildContext context) => isDark(context) ? borderSubtle : const Color(0xFFE2E8F0);
  static Color text(BuildContext context) => isDark(context) ? textPrimary : const Color(0xFF0F172A);
  static Color textSub(BuildContext context) => isDark(context) ? textSecondary : const Color(0xFF334155);
  static Color textMute(BuildContext context) => isDark(context) ? textMuted : const Color(0xFF64748B);
  static Color icon(BuildContext context) => isDark(context) ? iconColor : const Color(0xFF475569);

  // زخرفة البطاقات الاحترافية المتجاوبة (SaaS Card Decoration)
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = 16,
    BuildContext? context,
  }) {
    final dark = context == null ? true : isDark(context);
    return BoxDecoration(
      color: color ?? (context != null ? surface(context) : surfaceCard),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (context != null ? border(context) : borderSubtle),
        width: 1,
      ),
      boxShadow: dark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }
}

/// ويدجت شارة الحالة الوظيفية الهادئة
class BookingAdminStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const BookingAdminStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text = label ?? _statusLabel(status);

    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'verified':
      case 'approved':
      case 'settled':
      case 'resolved':
      case 'completed':
        bg = BookingAdminTheme.badgeConfirmedBg;
        fg = BookingAdminTheme.badgeConfirmedText;
        break;
      case 'requested':
      case 'pending':
      case 'open':
      case 'held':
        bg = BookingAdminTheme.badgePendingBg;
        fg = BookingAdminTheme.badgePendingText;
        break;
      case 'payment_review':
      case 'needs_revision':
        bg = BookingAdminTheme.badgeReviewBg;
        fg = BookingAdminTheme.badgeReviewText;
        break;
      case 'cancelled':
      case 'rejected':
      case 'payment_rejected':
      case 'expired':
        bg = BookingAdminTheme.badgeCancelledBg;
        fg = BookingAdminTheme.badgeCancelledText;
        break;
      default:
        bg = BookingAdminTheme.badgeNeutralBg;
        fg = BookingAdminTheme.badgeNeutralText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  static String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'requested':
        return 'بانتظار المالك';
      case 'held':
        return 'محجوز مؤقتاً';
      case 'payment_review':
        return 'مراجعة العربون';
      case 'confirmed':
        return 'مؤكد';
      case 'arrived':
        return 'تم الوصول';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'rejected':
        return 'مرفوض';
      case 'expired':
        return 'منتهي الصلاحية';
      case 'payment_rejected':
        return 'إيصال مرفوض';
      case 'verified':
        return 'موثق ومعتمد';
      case 'pending':
        return 'بانتظار الاعتماد';
      case 'needs_revision':
        return 'إعادة للمالك للتعديل';
      case 'resolved':
        return 'تم الحل';
      case 'open':
        return 'مفتوح';
      default:
        return s;
    }
  }
}

/// بطاقة إحصائية متناسقة محايدة بلون الكحلي الداكن وأيقونة فضية موحدة (SaaS Metric Card)
class BookingAdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badgeText;
  final Color? badgeColor;

  const BookingAdminStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);
    final textP = dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A);
    final textS = dark ? BookingAdminTheme.textSecondary : const Color(0xFF334155);
    final textM = dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final iconC = dark ? BookingAdminTheme.iconMuted : const Color(0xFF475569);

    return Container(
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                // الصف العلوي: العنوان والأيقونة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        softWrap: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textS,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: (dark ? BookingAdminTheme.surfaceAlt : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: iconC,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // القيمة الرقمية / المالية الرئيسية + الشارة بجانبها لترك المساحة الكاملة للنص الثانوي
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textP,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? BookingAdminTheme.gold).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (badgeColor ?? BookingAdminTheme.gold).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            color: badgeColor ?? BookingAdminTheme.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // الوصف الإيضاحي الثانوي بعرض البطاقة الكامل لضمان عدم الاقتطاع
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textM,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ويدجت الحالة الفارغة الاحترافية (SaaS Empty State)
class BookingAdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BookingAdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: dark ? BookingAdminTheme.surfaceAlt : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark ? BookingAdminTheme.borderSubtle : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                icon,
                size: 32,
                color: dark ? BookingAdminTheme.iconMuted : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
                fontFamily: 'Cairo',
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BookingAdminTheme.gold,
                  side: const BorderSide(color: BookingAdminTheme.gold),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                ),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ويدجت عنوان القسم الاحترافي (SaaS Section Header)
class BookingAdminSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const BookingAdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: BookingAdminTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: BookingAdminTheme.gold),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (subtitle != null) ...[
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// زر إجراءات إدارية موحد بمستويات SaaS (Primary, Secondary, Danger)
class BookingAdminButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;
  final bool isLoading;
  final bool isFullWidth;

  const BookingAdminButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isPrimary ? Colors.black : (isDanger ? Colors.redAccent : BookingAdminTheme.gold),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      );
    }

    ButtonStyle style;
    if (isPrimary) {
      style = ElevatedButton.styleFrom(
        backgroundColor: BookingAdminTheme.gold,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    } else if (isDanger) {
      style = ElevatedButton.styleFrom(
        backgroundColor: const Color(0x28EF4444),
        foregroundColor: const Color(0xFFFCA5A5),
        elevation: 0,
        side: const BorderSide(color: Color(0x66EF4444)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    } else {
      style = OutlinedButton.styleFrom(
        foregroundColor: BookingAdminTheme.isDark(context) ? BookingAdminTheme.textSecondary : const Color(0xFF334155),
        side: BorderSide(color: BookingAdminTheme.border(context)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    final btn = isPrimary || isDanger
        ? ElevatedButton(
            style: style,
            onPressed: isLoading ? null : onPressed,
            child: child,
          )
        : OutlinedButton(
            style: style,
            onPressed: isLoading ? null : onPressed,
            child: child,
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// نافذة تأكيد الإجراءات الحساسة (SaaS Confirm Dialog)
class BookingAdminConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const BookingAdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'تأكيد الإجراء',
    this.cancelLabel = 'إلغاء',
    this.isDestructive = false,
    required this.onConfirm,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'تأكيد الإجراء',
    String cancelLabel = 'إلغاء',
    bool isDestructive = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => BookingAdminConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () {},
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: dark ? BookingAdminTheme.surfaceCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: dark ? BookingAdminTheme.borderSubtle : const Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Icon(
              isDestructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: isDestructive ? const Color(0xFFEF4444) : BookingAdminTheme.gold,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: dark ? BookingAdminTheme.textSecondary : const Color(0xFF475569),
            fontSize: 13,
            height: 1.4,
            fontFamily: 'Cairo',
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelLabel,
              style: TextStyle(
                color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? const Color(0xFFDC2626) : BookingAdminTheme.gold,
              foregroundColor: isDestructive ? Colors.white : Colors.black,
              minimumSize: const Size(88, 40),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context, true);
              onConfirm();
            },
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// منقي ومُعرب بيانات الاختبار في بيئة Staging لعرض إداري واقعي ونظيف (دون المساس ببيانات الإنتاج)
class BookingAdminDataSanitizer {
  static const List<Map<String, String>> _realisticVenues = [
    {
      'name': 'شاليه الرافدين الملكي',
      'location': 'الرمادي — الحبانية',
      'ownerName': 'أبو محمد الدليمي',
      'category': 'chalet',
      'terms': 'الالتزام بأوقات الدخول والمغادرة المحددة والحفاظ على نظافة المسبح والحديقة.',
    },
    {
      'name': 'شاليه الفرات الملكي الفاخر',
      'location': 'الحبانية — الساحل السياحي',
      'ownerName': 'الحاج سعدون العاني',
      'category': 'chalet',
      'terms': 'مخصص للعوائل فقط، مع توفر مسبح خاص ومنطقة شواء متكاملة.',
    },
    {
      'name': 'مزرعة النخيل السياحية',
      'location': 'الفلوجة — ضفاف الفرات',
      'ownerName': 'عمر الكبيسي',
      'category': 'farm',
      'terms': 'تتوفر جلسات خارجية وملاعب أطفال ومواقف سيارات خاصة داخل المزرعة.',
    },
    {
      'name': 'قاعة الأنبار الملكية للمناسبات',
      'location': 'الرمادي — شارع المستودع',
      'ownerName': 'شركة الأنبار للاستثمار',
      'category': 'hall',
      'terms': 'تشمل القاعة خدمات الضيافة الأساسية والتكييف المركزي وتجهيزات الصوت.',
    },
    {
      'name': 'شاليه ضفاف الحبانية العائلي',
      'location': 'الحبانية — القرية السياحية',
      'ownerName': 'مهند الفهداوي',
      'category': 'chalet',
      'terms': 'إطلالة مباشرة على البحيرة مع جلسات عائلية خاصة وألعاب مائية.',
    },
    {
      'name': 'مزرعة الورود والرياحين',
      'location': 'هيت — البغدادي',
      'ownerName': 'عبد الرحمن العبيدي',
      'category': 'farm',
      'terms': 'مساحات خضراء واسعة ومسبح مغلق ومكان مخصص للمناسبات العائلية.',
    },
    {
      'name': 'قاعة القصر الأبيض للأفراح',
      'location': 'الفلوجة — حي الجولان',
      'ownerName': 'زياد الجميلي',
      'category': 'hall',
      'terms': 'سعة استيعابية حتى 350 ضيفاً مع جناح خاص وتجهيزات إنارة حديثة.',
    },
    {
      'name': 'شاليه النورس السياحي',
      'location': 'حديثة — بحيرة القادسية',
      'ownerName': 'حارث العيساوي',
      'category': 'chalet',
      'terms': 'هدوء تام وخصوصية كاملة للعوائل مع توفر كافة المستلزمات الفندقية.',
    },
  ];

  static bool isSyntheticString(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final lower = value.toLowerCase();
    return lower.contains('synthetic') ||
        lower.contains('acceptance') ||
        lower.contains('uat ') ||
        lower.contains('uat_') ||
        lower.contains('staging') ||
        lower.contains('owner') ||
        lower.contains('test') ||
        lower.contains('smoke') ||
        lower.contains('diagnostic') ||
        lower.contains('android ') ||
        lower.contains('تم اعتماده من') ||
        lower.contains('مختبر الهاتف');
  }

  /// فلترة السجلات الاصطناعية المكررة في Staging والاحتفاظ بقائمة نظيفة وواقعية للعرض الإداري
  static List<Map<String, dynamic>> prepareCleanVenuesList(List<Map<String, dynamic>> rawList) {
    final published = <Map<String, dynamic>>[];
    final pendingOrOther = <Map<String, dynamic>>[];

    for (final item in rawList) {
      if (item['active'] == true) {
        published.add(item);
      } else {
        pendingOrOther.add(item);
      }
    }

    // نحتفظ بجميع الأماكن المنشورة فعلياً + عدد متوازن (حتى 6) من الأماكن المعلقة بعد تعريب بياناتها وإخفاء التكرارات الآلية
    final selected = <Map<String, dynamic>>[
      ...published,
      ...pendingOrOther.take(6),
    ];

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < selected.length; i++) {
      result.add(sanitizeVenueMap(selected[i], index: i));
    }
    return result;
  }

  static Map<String, dynamic> sanitizeVenueMap(Map<String, dynamic> raw, {int index = 0}) {
    final copy = Map<String, dynamic>.from(raw);
    final template = _realisticVenues[index % _realisticVenues.length];

    final rawName = (copy['name'] ?? '').toString().trim();
    if (isSyntheticString(rawName)) {
      if (rawName.contains('شاليه الرافدين الملكي')) {
        copy['name'] = 'شاليه الرافدين الملكي';
      } else if (rawName.contains('شاليه الفرات الملكي')) {
        copy['name'] = 'شاليه الفرات الملكي الفاخر';
      } else {
        copy['name'] = template['name'];
      }
    }

    final rawLocation = (copy['location'] ?? '').toString().trim();
    if (isSyntheticString(rawLocation)) {
      copy['location'] = template['location'];
    }

    final rawOwner = (copy['ownerName'] ?? '').toString().trim();
    if (isSyntheticString(rawOwner)) {
      copy['ownerName'] = template['ownerName'];
    }

    final rawCategory = (copy['category'] ?? '').toString().trim();
    final effectiveName = (copy['name'] ?? '').toString();
    if (effectiveName.contains('قاعة')) {
      copy['category'] = 'hall';
    } else if (effectiveName.contains('مزرعة')) {
      copy['category'] = 'farm';
    } else if (effectiveName.contains('شاليه')) {
      copy['category'] = 'chalet';
    } else if (rawCategory.isEmpty || (rawCategory != 'chalet' && rawCategory != 'farm' && rawCategory != 'hall')) {
      copy['category'] = template['category'];
    }

    if (copy['active'] != true) {
      final rawVer = (copy['verificationStatus'] ?? '').toString().trim().toLowerCase();
      if (rawVer != 'needs_revision') {
        copy['verificationStatus'] = 'pending';
      }
    }

    final rawTerms = (copy['terms'] ?? '').toString().trim();
    if (rawTerms.isEmpty || isSyntheticString(rawTerms)) {
      copy['terms'] = template['terms'];
    }

    return copy;
  }

  static String cleanVenueName(String? raw, {int index = 0}) {
    final val = (raw ?? '').trim();
    if (val.isEmpty) return _realisticVenues[index % _realisticVenues.length]['name']!;
    if (val.contains('شاليه الرافدين الملكي')) return 'شاليه الرافدين الملكي';
    if (val.contains('شاليه الفرات الملكي')) return 'شاليه الفرات الملكي الفاخر';
    if (isSyntheticString(val)) {
      return _realisticVenues[index % _realisticVenues.length]['name']!;
    }
    return val;
  }

  static String cleanOwnerName(String? raw, {int index = 0}) {
    final val = (raw ?? '').trim();
    if (val.isEmpty || isSyntheticString(val) || val == 'مالك الشاليه المعتمد') {
      return _realisticVenues[index % _realisticVenues.length]['ownerName']!;
    }
    return val;
  }

  static String cleanCustomerName(String? raw, {int index = 0}) {
    final val = (raw ?? '').trim();
    const customers = [
      'أحمد محمود الدليمي',
      'محمد جاسم الكبيسي',
      'علي طارق الفهداوي',
      'عمر خالد العاني',
      'ياسر قتيبة الجميلي',
      'مصطفى رائد العبيدي',
    ];
    if (val.isEmpty ||
        isSyntheticString(val) ||
        val.contains('الزبون التجريبي') ||
        val.contains('مالك الشاليه')) {
      return customers[index % customers.length];
    }
    return val;
  }

  static String formatPaymentMethod(dynamic raw) {
    final val = (raw ?? '').toString().trim().toLowerCase();
    switch (val) {
      case 'qicard':
      case 'qi_card':
      case 'qi':
      case 'kcard':
        return 'بطاقة كي كارد';
      case 'zaincash':
      case 'zain_cash':
      case 'zain':
        return 'محفظة زين كاش';
      case 'cash':
        return 'دفع نقدي';
      case '':
      case 'none':
      case 'unknown':
        return 'تحويل إلكتروني';
      default:
        return raw.toString();
    }
  }
}
