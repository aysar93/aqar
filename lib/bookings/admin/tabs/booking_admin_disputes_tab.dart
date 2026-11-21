import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';
import '../../booking_screen.dart' show bookingCall;
import '../../booking_extras.dart' show BookingSupportEvidenceDialog;
import '../../booking_operations.dart' show BookingSecureEvidenceViewer;

class BookingAdminDisputesTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? disputesStream;

  const BookingAdminDisputesTab({super.key, this.disputesStream});

  @override
  State<BookingAdminDisputesTab> createState() => _BookingAdminDisputesTabState();
}

class _BookingAdminDisputesTabState extends State<BookingAdminDisputesTab>
    with AutomaticKeepAliveClientMixin {
  String _statusFilter = 'all'; // all, open, under_review, awaiting_customer, awaiting_owner, resolved, closed
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final stream = widget.disputesStream ??
        FirebaseFirestore.instance
            .collection('booking_support')
            .orderBy('updatedAt', descending: true)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذر تحميل تذاكر النزاعات: ${snap.error}',
                style: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold));
        }

        final docs = snap.data?.docs.map((d) {
          final m = d.data();
          m['_id'] = d.id;
          return m;
        }).toList() ?? [];

        int countOpen = 0;
        int countReview = 0;
        int countResolved = 0;

        for (final t in docs) {
          final s = t['status']?.toString();
          if (s == 'open') {
            countOpen++;
          } else if (s == 'under_review' || s == 'awaiting_customer' || s == 'awaiting_owner') {
            countReview++;
          } else if (s == 'resolved' || s == 'closed') {
            countResolved++;
          }
        }

        final filtered = docs.where((t) {
          final s = t['status']?.toString() ?? 'open';
          if (_statusFilter == 'open' && s != 'open') {
            return false;
          }
          if (_statusFilter == 'under_review' && !['under_review', 'awaiting_customer', 'awaiting_owner'].contains(s)) {
            return false;
          }
          if (_statusFilter == 'resolved' && !['resolved', 'closed'].contains(s)) {
            return false;
          }

          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            final subj = (t['subject'] ?? '').toString().toLowerCase();
            final user = (t['userName'] ?? '').toString().toLowerCase();
            final venue = (t['venueName'] ?? '').toString().toLowerCase();
            final bId = (t['bookingId'] ?? '').toString().toLowerCase();
            if (!subj.contains(q) && !user.contains(q) && !venue.contains(q) && !bId.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // بطاقة الإحصائيات السريعة للنزاعات
            Row(
              children: [
                Expanded(
                  child: _statCard('نزاعات جديدة', countOpen.toString(), Colors.orangeAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard('قيد التحكيم والمراجعة', countReview.toString(), BookingAdminTheme.gold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard('تمت التسوية والحل', countResolved.toString(), Colors.greenAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // شريط البحث والفلترة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BookingAdminTheme.cardDecoration(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, size: 20, color: BookingAdminTheme.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نظام التحكيم وإدارة النزاعات وبلاغات الحجوزات',
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
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 12, fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'بحث بالموضوع، اسم المستخدم، المكان، أو رقم الحجز...',
                      hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'Cairo'),
                      prefixIcon: const Icon(Icons.search, size: 18, color: BookingAdminTheme.gold),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: BookingAdminTheme.surfaceSecondary(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('كل النزاعات', 'all'),
                        _chip('مفتوحة جديدة ($countOpen)', 'open'),
                        _chip('قيد التحكيم ($countReview)', 'under_review'),
                        _chip('تمت التسوية ($countResolved)', 'resolved'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قائمة التذاكر
            if (filtered.isEmpty)
              BookingAdminEmptyState(
                icon: Icons.check_circle_outline,
                title: 'لا توجد نزاعات تطابق الفلتر',
                description: 'جميع النزاعات والبلاغات معالجة أو لا توجد تذاكر حالية.',
                actionLabel: _statusFilter != 'all' || _searchQuery.isNotEmpty ? 'عرض الكل' : null,
                onAction: () {
                  _searchCtrl.clear();
                  setState(() {
                    _statusFilter = 'all';
                    _searchQuery = '';
                  });
                },
              )
            else
              Column(
                children: [
                  for (final ticket in filtered) ...[
                    _buildDisputeCard(ticket),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _statusFilter = value);
        },
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected ? BookingAdminTheme.gold : BookingAdminTheme.textMute(context),
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(color: selected ? BookingAdminTheme.gold : BookingAdminTheme.border(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'open').toString();
    final role = (t['openedByRole'] ?? 'user').toString();
    final msgs = (t['messages'] as List?)?.length ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: InkWell(
        onTap: () => _openDisputeDetails(t),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BookingAdminTheme.surfaceSecondary(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      role == 'customer' ? Icons.person_outline : Icons.business_outlined,
                      size: 18,
                      color: BookingAdminTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['subject'] ?? 'نزاع حجز بدون عنوان',
                          style: TextStyle(
                            color: BookingAdminTheme.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          '${t['userName'] ?? 'مستخدم'} • ${t['venueName'] ?? 'المكان'}',
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
                    status: status == 'resolved' || status == 'closed' ? 'approved' : status == 'open' ? 'pending' : 'active',
                    label: _statusLabel(status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BookingAdminTheme.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t['message'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BookingAdminTheme.textSub(context),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم الحجز: ${t['bookingId'] ?? 'غير محدد'}',
                    style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.forum_outlined, size: 14, color: BookingAdminTheme.gold),
                      const SizedBox(width: 4),
                      Text(
                        '$msgs رسالة',
                        style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDisputeDetails(Map<String, dynamic> t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DisputeDetailSheet(ticket: t),
    );
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'نزاع جديد مفتوح';
      case 'under_review':
        return 'قيد التحكيم والمراجعة';
      case 'awaiting_customer':
        return 'بانتظار إفادة الزبون';
      case 'awaiting_owner':
        return 'بانتظار إفادة المالك';
      case 'resolved':
        return 'تم حل النزاع';
      case 'closed':
        return 'مغلق نهائياً';
      default:
        return s;
    }
  }
}

class _DisputeDetailSheet extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const _DisputeDetailSheet({required this.ticket});

  @override
  State<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends State<_DisputeDetailSheet> {
  final TextEditingController _replyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = widget.ticket['_id'] ?? widget.ticket['ticketId'];
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('booking_support').doc(ticketId).snapshots(),
          builder: (context, snap) {
            final t = snap.data?.data() ?? widget.ticket;
            final msgs = (t['messages'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
            final evidenceList = (t['evidence'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
            final currentStatus = (t['status'] ?? 'open').toString();

            return Container(
              decoration: BoxDecoration(
                color: BookingAdminTheme.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // شريط المقبض العلوي
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: BookingAdminTheme.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // عنوان التذكرة وحالتها
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_rounded, color: BookingAdminTheme.gold, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t['subject'] ?? 'تفاصيل النزاع',
                              style: TextStyle(
                                color: BookingAdminTheme.text(context),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          BookingAdminStatusBadge(
                            status: currentStatus == 'resolved' ? 'approved' : currentStatus == 'open' ? 'pending' : 'active',
                            label: _BookingAdminDisputesTabState._statusLabel(currentStatus),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // جسم الرسائل
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // بيانات الحجز والأطراف
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BookingAdminTheme.surfaceSecondary(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: BookingAdminTheme.border(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('رقم الحجز: ${t['bookingId']}', style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'monospace')),
                                const SizedBox(height: 2),
                                Text('المكان: ${t['venueName']}', style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                const SizedBox(height: 2),
                                Text('العميل: ${t['userName']} • نوع النزاع: ${t['type'] ?? 'عام'}', style: TextStyle(color: BookingAdminTheme.textSub(context), fontSize: 11, fontFamily: 'Cairo')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'سجل المراسلات والتحكيم:',
                            style: TextStyle(color: BookingAdminTheme.gold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 10),

                          for (final msg in msgs) ...[
                            _buildMessageBubble(msg),
                          ],

                          // قسم الأدلة والمستندات المرفقة
                          _buildEvidenceSection(ticketId, currentStatus, evidenceList),

                          const SizedBox(height: 16),
                          // أزرار اتخاذ القرار الإداري
                          const Text(
                            'قرارات التحكيم الإدارية:',
                            style: TextStyle(color: BookingAdminTheme.gold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _actionBtn('طلب إفادة الزبون', () => _changeStatus(ticketId, 'awaiting_customer')),
                              _actionBtn('طلب إفادة المالك', () => _changeStatus(ticketId, 'awaiting_owner')),
                              _actionBtn('تسوية وحل النزاع', () => _resolveDispute(ticketId), isPrimary: true),
                              _actionBtn('إغلاق نهائي', () => _changeStatus(ticketId, 'closed'), isDestructive: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // صندوق إرسال الرد
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BookingAdminTheme.surface(context),
                        border: Border(top: BorderSide(color: BookingAdminTheme.border(context))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyCtrl,
                              style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 12, fontFamily: 'Cairo'),
                              decoration: InputDecoration(
                                hintText: 'اكتب رد التحكيم الإداري هنا...',
                                hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'Cairo'),
                                filled: true,
                                fillColor: BookingAdminTheme.surfaceSecondary(context),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_busy)
                            const CircularProgressIndicator(color: BookingAdminTheme.gold)
                          else
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: BookingAdminTheme.gold),
                              onPressed: () => _sendAdminReply(ticketId),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final role = msg['senderRole']?.toString() ?? 'user';
    final isAdmin = role == 'admin';
    final isCustomer = role == 'customer';

    final Color bubbleColor = isAdmin
        ? BookingAdminTheme.gold.withValues(alpha: 0.15)
        : isCustomer
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.12);

    final Color borderColor = isAdmin
        ? BookingAdminTheme.gold.withValues(alpha: 0.4)
        : isCustomer
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.green.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${msg['senderName'] ?? (isAdmin ? 'إدارة المنصة' : 'مستخدم')} (${isAdmin ? 'الإدارة' : isCustomer ? 'الزبون' : 'المالك'})',
                style: TextStyle(
                  color: isAdmin ? BookingAdminTheme.gold : isCustomer ? Colors.blue.shade300 : Colors.green.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            msg['text']?.toString() ?? '',
            style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 12, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {bool isPrimary = false, bool isDestructive = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? BookingAdminTheme.gold : isDestructive ? Colors.red.shade800 : BookingAdminTheme.surfaceSecondary(context),
        foregroundColor: isPrimary ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Future<void> _sendAdminReply(String ticketId) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await bookingCall('addBookingSupportMessage', {
        'ticketId': ticketId,
        'message': text,
      });
      _replyCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الرد: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String ticketId, String newStatus) async {
    setState(() => _busy = true);
    try {
      await bookingCall('updateBookingSupportTicket', {
        'ticketId': ticketId,
        'status': newStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة النزاع بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الحالة: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveDispute(String ticketId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        title: Text('تسوية وحل النزاع', style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'اكتب حيثيات وقرار التسوية النهائي...',
            hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo'),
            filled: true,
            fillColor: BookingAdminTheme.surfaceSecondary(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BookingAdminTheme.gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحل'),
          ),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      setState(() => _busy = true);
      try {
        await bookingCall('updateBookingSupportTicket', {
          'ticketId': ticketId,
          'status': 'resolved',
          'resolution': ctrl.text.trim(),
          'response': 'قرار التحكيم النهائي: ${ctrl.text.trim()}',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت تسوية النزاع بنجاح وإشعار الأطراف', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تسجيل الحل: $e', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Widget _buildEvidenceSection(String ticketId, String currentStatus, List<Map<String, dynamic>> evidenceList) {
    final isClosed = currentStatus == 'resolved' || currentStatus == 'closed';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BookingAdminTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingAdminTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attachment_rounded, size: 18, color: BookingAdminTheme.gold),
              const SizedBox(width: 8),
              Text(
                'الأدلة والمستندات المرفقة (${evidenceList.length})',
                style: const TextStyle(
                  color: BookingAdminTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              if (!isClosed)
                TextButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: BookingAdminTheme.gold),
                  label: const Text('إرفاق دليل', style: TextStyle(fontSize: 11, color: BookingAdminTheme.gold, fontFamily: 'Cairo')),
                  onPressed: () => _promptAttachEvidence(ticketId),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('المرفقات مقفلة', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (evidenceList.isEmpty)
            Text(
              'لا توجد أدلة أو مستندات مرفقة بهذا النزاع حالياً.',
              style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 11, fontFamily: 'Cairo'),
            )
          else
            Column(
              children: [
                for (final ev in evidenceList)
                  _buildEvidenceItem(ev),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(Map<String, dynamic> ev) {
    final fileName = ev['fileName']?.toString() ?? 'ملف مرفق';
    final fileType = ev['fileType']?.toString() ?? '';
    final fileSize = (ev['fileSize'] is num) ? (ev['fileSize'] as num).toInt() : 0;
    final role = ev['uploadedByRole']?.toString() ?? 'user';
    final roleName = role == 'admin' ? 'الإدارة' : (role == 'customer' ? 'الزبون' : 'المالك');
    final isPdf = fileType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
    final sizeKb = (fileSize / 1024).toStringAsFixed(1);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => BookingSecureEvidenceViewer.open(context, ev),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: BookingAdminTheme.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BookingAdminTheme.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              size: 20,
              color: isPdf ? Colors.red.shade400 : Colors.blue.shade400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BookingAdminTheme.text(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'بواسطة: $roleName • الحجم: $sizeKb KB • ${_formatDate(ev['uploadedAt'])}',
                    style: TextStyle(
                      color: BookingAdminTheme.textMute(context),
                      fontSize: 9,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (ev['note'] != null && ev['note'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'ملاحظة: ${ev['note']}',
                        style: TextStyle(color: BookingAdminTheme.textSub(context), fontSize: 10, fontFamily: 'Cairo'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new,
              size: 14,
              color: BookingAdminTheme.gold,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptAttachEvidence(String ticketId) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BookingSupportEvidenceDialog(ticketId: ticketId),
    );

    if (value != null && mounted) {
      setState(() => _busy = true);
      try {
        await bookingCall('attachBookingDisputeEvidence', {
          'ticketId': ticketId,
          ...value,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرفاق الدليل وتوثيقه في سجل التدقيق بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إرفاق الدليل: $e', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return '';
      }
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
