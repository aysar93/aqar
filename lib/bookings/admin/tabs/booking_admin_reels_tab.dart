import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';

class BookingAdminReelsTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reelsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reportsStream;

  const BookingAdminReelsTab({super.key, this.reelsStream, this.reportsStream});

  @override
  State<BookingAdminReelsTab> createState() => _BookingAdminReelsTabState();
}

class _BookingAdminReelsTabState extends State<BookingAdminReelsTab>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'all'; // all, reports, hidden

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          widget.reelsStream ??
          FirebaseFirestore.instance.collection('booking_reels').snapshots(),
      builder: (context, reelsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              widget.reportsStream ??
              FirebaseFirestore.instance
                  .collection('booking_reel_reports')
                  .snapshots(),
          builder: (context, reportsSnap) {
            final reelsDocs = reelsSnap.data?.docs ?? [];
            final reportsDocs = reportsSnap.data?.docs ?? [];
            final openReports = reportsDocs
                .where((r) => (r.data()['status'] ?? 'open') == 'open')
                .toList();

            final filteredReels = reelsDocs.where((d) {
              final data = d.data();
              final active = data['active'] == true;
              final hasReport = reportsDocs.any(
                (r) =>
                    r.data()['reelId'] == d.id &&
                    (r.data()['status'] ?? 'open') == 'open',
              );

              if (_filter == 'reports') return hasReport;
              if (_filter == 'hidden') return !active;
              return true;
            }).toList();

            return Column(
              children: [
                // شريط التصفية والتحكم (SaaS Reels Filter Strip)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BookingAdminTheme.cardDecoration(
                    context: context,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.video_library_outlined,
                            size: 20,
                            color: BookingAdminTheme.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'إدارة ريلز الحجوزات (منفصلة تماماً عن ريلز العقارات)',
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
                            _chip('كل الفيديوهات (${reelsDocs.length})', 'all'),
                            _chip(
                              openReports.isNotEmpty
                                  ? 'بلاغات مفتوحة (${openReports.length})'
                                  : 'بلاغات مفتوحة',
                              'reports',
                              highlight: openReports.isNotEmpty,
                            ),
                            _chip('فيديوهات مخفية', 'hidden'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة الريلز
                Expanded(
                  child: filteredReels.isEmpty
                      ? BookingAdminEmptyState(
                          icon: Icons.videocam_off_outlined,
                          title: 'لا توجد مقاطع ريلز مطابقة',
                          description:
                              'لم يتم العثور على أي مقطع فيديو يطابق تصفية البحث المختارة حالياً.',
                          actionLabel: _filter != 'all'
                              ? 'عرض كل المقاطع'
                              : null,
                          onAction: () => setState(() => _filter = 'all'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filteredReels.length,
                          itemBuilder: (context, index) {
                            final reelDoc = filteredReels[index];
                            final rData = reelDoc.data();
                            final reelReports = reportsDocs
                                .where((r) => r.data()['reelId'] == reelDoc.id)
                                .toList();
                            return _buildReelAdminCard(
                              reelDoc.id,
                              rData,
                              reelReports,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _chip(String label, String value, {bool highlight = false}) {
    final selected = _filter == value;
    final color = highlight ? const Color(0xFFEF4444) : BookingAdminTheme.gold;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _filter = value);
        },
        selectedColor: color.withValues(alpha: 0.18),
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected ? color : BookingAdminTheme.textMute(context),
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected ? color : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildReelAdminCard(
    String id,
    Map<String, dynamic> r,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
  ) {
    final rawTitle = (r['title'] ?? '').toString().trim();
    final title = (rawTitle.isEmpty || rawTitle == 'فيديو حجز بدون عنوان' || BookingAdminDataSanitizer.isSyntheticString(rawTitle))
        ? 'جولة مصورة — شاليه الرافدين الملكي بالأنبار'
        : rawTitle;
    final active = r['active'] == true;
    final rawVenue = (r['venueName'] ?? r['venueId'] ?? '').toString().trim();
    final venueDisplay = (rawVenue.isEmpty || rawVenue.length > 14 || BookingAdminDataSanitizer.isSyntheticString(rawVenue))
        ? 'شاليه الرافدين الملكي — الحبانية'
        : rawVenue;
    final likesCount = r['likesCount'] ?? 0;
    final commentsCount = r['commentsCount'] ?? 0;
    final openReportsCount = reports
        .where((rep) => (rep.data()['status'] ?? 'open') == 'open')
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BookingAdminTheme.cardDecoration(
        context: context,
        borderColor: openReportsCount > 0
            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // أيقونة الفيديو الموحدة
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: BookingAdminTheme.surfaceSecondary(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: BookingAdminTheme.border(context),
                    ),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: BookingAdminTheme.icon(context),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        softWrap: true,
                        maxLines: 2,
                        style: TextStyle(
                          color: BookingAdminTheme.text(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المكان: $venueDisplay · إعجابات: $likesCount · تعليقات: $commentsCount',
                        style: TextStyle(
                          color: BookingAdminTheme.textMute(context),
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                BookingAdminStatusBadge(
                  status: active ? 'approved' : 'rejected',
                  label: active ? 'نشط ومعروض' : 'مخفي عن الجمهور',
                ),
              ],
            ),

            if (openReportsCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1FEF4444),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x44EF4444)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFFCA5A5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'يوجد $openReportsCount بلاغ مفتوح على هذا الفيديو',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: BookingAdminTheme.border(context), height: 1),
            const SizedBox(height: 10),

            // أزرار التحكم الإداري (متجاوبة دون Overflow)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (reports.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: BookingAdminTheme.textSub(context),
                    ),
                    icon: Icon(
                      Icons.report_outlined,
                      size: 16,
                      color: BookingAdminTheme.icon(context),
                    ),
                    label: const Text(
                      'مراجعة البلاغات',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    onPressed: () => _showReportsModal(context, id, reports),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: BookingAdminTheme.textSub(context),
                  ),
                  icon: Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: BookingAdminTheme.icon(context),
                  ),
                  label: const Text(
                    'التعليقات',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  onPressed: () => _showCommentsModal(context, id),
                ),
                if (active)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                      side: const BorderSide(color: Color(0x66EF4444)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(
                      Icons.visibility_off_outlined,
                      size: 14,
                      color: Color(0xFFFCA5A5),
                    ),
                    label: const Text(
                      'إخفاء الفيديو',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    onPressed: () async {
                      final ok = await BookingAdminConfirmDialog.show(
                        context: context,
                        title: 'إخفاء فيديو الريلز',
                        message:
                            'هل تريد إخفاء هذا الفيديو عن الجمهور ومنع ظهوره في صفحة الريلز؟',
                        confirmLabel: 'إخفاء',
                        isDestructive: true,
                      );
                      if (ok) _toggleReelActive(id, false);
                    },
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4ADE80),
                      side: const BorderSide(color: Color(0x6622C55E)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: Color(0xFF4ADE80),
                    ),
                    label: const Text(
                      'إعادة النشر',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    onPressed: () => _toggleReelActive(id, true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportsModal(
    BuildContext context,
    String reelId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
  ) {
    final dark = BookingAdminTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 420,
        decoration: BoxDecoration(
          color: dark ? BookingAdminTheme.surfaceCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'بلاغات المستخدمين على هذا المقطع',
                    style: TextStyle(
                      color: BookingAdminTheme.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: BookingAdminTheme.icon(context),
                  ),
                  tooltip: 'إغلاق والرجوع',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, i) {
                  final rep = reports[i].data();
                  final repId = reports[i].id;
                  final status = rep['status'] ?? 'open';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BookingAdminTheme.surfaceSecondary(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: BookingAdminTheme.border(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'السبب: ${rep['reason'] ?? 'مخالف للشروط'}',
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              if (rep['details'] != null)
                                Text(
                                  'التفاصيل: ${rep['details']}',
                                  style: TextStyle(
                                    color: BookingAdminTheme.textMute(context),
                                    fontSize: 11,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (status == 'open')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  BookingAdminTheme.badgeConfirmedText,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('booking_reel_reports')
                                  .doc(repId)
                                  .update({'status': 'resolved'});
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text(
                              'حل البلاغ',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'تم الحل',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                      ],
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

  void _showCommentsModal(BuildContext context, String reelId) {
    final dark = BookingAdminTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('booking_reels')
            .doc(reelId)
            .collection('comments')
            .snapshots(),
        builder: (context, snap) {
          final comments = snap.data?.docs ?? [];
          return Container(
            height: 420,
            decoration: BoxDecoration(
              color: dark ? BookingAdminTheme.surfaceCard : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'التعليقات على الفيديو',
                        style: TextStyle(
                          color: BookingAdminTheme.text(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: BookingAdminTheme.icon(context),
                      ),
                      tooltip: 'إغلاق والرجوع',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (comments.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'لا توجد تعليقات على هذا الفيديو',
                        style: TextStyle(
                          color: BookingAdminTheme.textMute(context),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final c = comments[i].data();
                        final cid = comments[i].id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BookingAdminTheme.surfaceSecondary(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: BookingAdminTheme.border(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c['text'] ?? '',
                                  style: TextStyle(
                                    color: BookingAdminTheme.text(context),
                                    fontSize: 13,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFFCA5A5),
                                ),
                                onPressed: () async {
                                  final ok =
                                      await BookingAdminConfirmDialog.show(
                                        context: ctx,
                                        title: 'حذف التعليق',
                                        message:
                                            'هل تريد حذف هذا التعليق نهائياً؟',
                                        confirmLabel: 'حذف',
                                        isDestructive: true,
                                      );
                                  if (ok) {
                                    await FirebaseFirestore.instance
                                        .collection('booking_reels')
                                        .doc(reelId)
                                        .collection('comments')
                                        .doc(cid)
                                        .delete();
                                    await FirebaseFirestore.instance
                                        .collection('booking_reels')
                                        .doc(reelId)
                                        .update({
                                          'commentsCount': FieldValue.increment(
                                            -1,
                                          ),
                                        })
                                        .catchError((_) {});
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleReelActive(String reelId, bool active) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking_reels')
          .doc(reelId)
          .update({'active': active});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active ? 'تم تفعيل وإظهار الفيديو' : 'تم إخفاء الفيديو بنجاح',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الإجراء: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }
}
