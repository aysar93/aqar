import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';

class BookingAdminAuditTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? auditStream;

  const BookingAdminAuditTab({super.key, this.auditStream});

  @override
  State<BookingAdminAuditTab> createState() => _BookingAdminAuditTabState();
}

class _BookingAdminAuditTabState extends State<BookingAdminAuditTab>
    with AutomaticKeepAliveClientMixin {
  String _auditType = 'all'; // all, venues, bookings, payments

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final uid = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser?.uid
        : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // بطاقة صلاحيات المستخدم الحالي (SaaS Current Admin Identity)
        _buildUserPermissionsCard(uid),
        const SizedBox(height: 16),

        // ضوابط وقواعد الأمان المشددة (Security Controls)
        _buildSecurityGuardsCard(),
        const SizedBox(height: 16),

        // شريط تصفية سجل العمليات
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BookingAdminTheme.cardDecoration(context: context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.security_update_good_outlined,
                    size: 20,
                    color: BookingAdminTheme.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سجل التدقيق والعمليات الإدارية في النظام (Audit Trail)',
                      style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('كل السجلات', 'all'),
                    _chip('عمليات الأماكن', 'venues'),
                    _chip('إجراءات الحجوزات', 'bookings'),
                    _chip('تعديلات الحسابات المالية', 'payments'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // سجل العمليات المباشر
        _buildAuditLogsList(),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final selected = _auditType == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _auditType = value);
        },
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.textMute(context),
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildUserPermissionsCard(String? uid) {
    if (uid == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BookingAdminTheme.cardDecoration(context: context),
        child: Text(
          'المستخدم غير مسجل الدخول حالياً',
          style: TextStyle(
            color: BookingAdminTheme.textMute(context),
            fontFamily: 'Cairo',
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final isAdmin = data['isAdmin'] == true;
        final canReviewPayments = data['canReviewBookingPayments'] == true;
        final canManageAccounts = data['canManagePaymentAccounts'] == true;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BookingAdminTheme.cardDecoration(
            context: context,
            borderColor: BookingAdminTheme.gold.withValues(alpha: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: BookingAdminTheme.goldSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      size: 20,
                      color: BookingAdminTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صلاحيات الحساب الحالي',
                          style: TextStyle(
                            color: BookingAdminTheme.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          '${data['name'] ?? data['email'] ?? uid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BookingAdminTheme.textMute(context),
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  BookingAdminStatusBadge(
                    status: isAdmin ? 'approved' : 'pending',
                    label: isAdmin
                        ? 'مدير نظام معتمد'
                        : 'مستخدم محدود الصلاحية',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                children: [
                  _permItem('صلاحية إدارة عامة للنظام (isAdmin)', isAdmin),
                  const SizedBox(height: 8),
                  _permItem(
                    'مراجعة وتدقيق العربون والعمليات المالية',
                    canReviewPayments || isAdmin,
                  ),
                  const SizedBox(height: 8),
                  _permItem(
                    'تعديل وإدارة حسابات الدفع اليدوي (Qi Card & Zain Cash)',
                    canManageAccounts || isAdmin,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _permItem(String label, bool granted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: BookingAdminTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: granted
              ? const Color(0xFF22C55E).withValues(alpha: 0.3)
              : BookingAdminTheme.border(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: granted ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: granted
                    ? BookingAdminTheme.text(context)
                    : BookingAdminTheme.textMute(context),
                fontSize: 12,
                fontWeight: granted ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityGuardsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: BookingAdminTheme.icon(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الضوابط الأمنية المحققة على مستوى الخادم وقواعد البيانات:',
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '• منع المالك من اعتماد مكانه أو تعديل بيانات أماكن الآخرين (فحص إلزامي بالخادم).\n'
            '• منع نشر أي مكان للعامة قبل موافقة الإدارة وتوثيق الملكية الرسمية.\n'
            '• اعتماد ومراجعة الإيصالات المالية مقصورة على المديرين والمراجعين الماليين فقط.\n'
            '• تسجيل كل عملية إدارية بتوقيع زمني وUID الفاعل في مجموعات التدقيق المحمية.',
            style: TextStyle(
              color: BookingAdminTheme.textMute(context),
              fontSize: 12,
              height: 1.6,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    final actionAuditStream =
        widget.auditStream ??
        (Firebase.apps.isEmpty
            ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
            : FirebaseFirestore.instance
                  .collection('booking_action_audit')
                  .limit(30)
                  .snapshots());

    final venueAuditStream = widget.auditStream != null || Firebase.apps.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('booking_venue_audit')
              .limit(30)
              .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: actionAuditStream,
      builder: (context, actionSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: venueAuditStream,
          builder: (context, venueSnap) {
            final actionDocs =
                actionSnap.data?.docs.map((d) {
                  final map = d.data();
                  map['_type'] = 'action';
                  map['_id'] = d.id;
                  return map;
                }).toList() ??
                [];

            final venueDocs =
                venueSnap.data?.docs.map((d) {
                  final map = d.data();
                  map['_type'] = 'venue';
                  map['_id'] = d.id;
                  return map;
                }).toList() ??
                [];

            final allLogs = [...actionDocs, ...venueDocs];

            final filteredLogs = allLogs.where((log) {
              final type = log['_type'] as String;
              final action = (log['action'] ?? '').toString().toLowerCase();

              if (_auditType == 'venues') {
                return type == 'venue' || action.contains('venue');
              } else if (_auditType == 'bookings') {
                return type == 'action' && !action.contains('payment');
              } else if (_auditType == 'payments') {
                return action.contains('payment') || action.contains('deposit');
              }
              return true;
            }).toList();

            if (filteredLogs.isEmpty) {
              return BookingAdminEmptyState(
                icon: Icons.history_edu_outlined,
                title: 'سجل العمليات فارغ',
                description:
                    'لم تسجل أي عمليات إدارية تطابق الفلتر المختار حالياً.',
                actionLabel: _auditType != 'all' ? 'عرض كل السجلات' : null,
                onAction: () => setState(() => _auditType = 'all'),
              );
            }

            return Column(
              children: [
                for (final log in filteredLogs) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BookingAdminTheme.cardDecoration(
                      context: context,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: BookingAdminTheme.surfaceSecondary(
                                  context,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                log['_type'] == 'venue'
                                    ? Icons.villa_outlined
                                    : Icons.bookmark_outline_rounded,
                                size: 16,
                                color: BookingAdminTheme.gold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _actionLabel(log['action']),
                                softWrap: true,
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(log['createdAt'] ?? log['timestamp']),
                              style: TextStyle(
                                color: BookingAdminTheme.textMute(context),
                                fontSize: 11,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'المعرف المستهدف: ${log['bookingId'] ?? log['venueId'] ?? log['_id'] ?? 'غير محدد'}',
                          style: TextStyle(
                            color: BookingAdminTheme.textMute(context),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (log['adminUid'] != null ||
                            log['actorUid'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'المشرف الفاعل: ${log['adminEmail'] ?? log['adminUid'] ?? log['actorUid']}',
                            style: TextStyle(
                              color: BookingAdminTheme.textSub(context),
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                        if (log['reason'] != null &&
                            log['reason'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: BookingAdminTheme.surfaceSecondary(
                                context,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'السبب المسجل: ${log['reason']}',
                              style: TextStyle(
                                color: BookingAdminTheme.textSub(context),
                                fontSize: 11,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  static String _actionLabel(dynamic act) {
    final a = (act ?? '').toString().toLowerCase();
    switch (a) {
      case 'approve':
        return 'الموافقة على طلب الحجز';
      case 'reject':
        return 'رفض طلب الحجز';
      case 'arrive':
        return 'تسجيل وصول الضيف (Check-in)';
      case 'complete':
        return 'إكمال الحجز وتسوية المدة';
      case 'cancel':
        return 'إلغاء الحجز من قبل الإدارة';
      case 'confirmpayment':
        return 'اعتماد الإيصال وتأكيد العربون';
      case 'rejectpayment':
        return 'رفض الإيصال المالي';
      case 'settlerefund':
        return 'تسوية استرداد المبلغ';
      case 'savebookingvenue':
        return 'حفظ وتحديث بيانات المكان';
      case 'reviewbookingownershipproof':
        return 'مراجعة وتوثيق إثبات الملكية';
      default:
        return act?.toString() ?? 'إجراء إداري';
    }
  }

  static String _formatTime(dynamic val) {
    if (val == null) return 'غير محدد';
    DateTime? dt;
    if (val is Timestamp) dt = val.toDate();
    if (val is num) dt = DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) dt = DateTime.tryParse(val);
    if (dt == null) return val.toString();
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
