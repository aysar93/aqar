import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';

class BookingAdminCalendarTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? closuresStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? venuesStream;

  const BookingAdminCalendarTab({
    super.key,
    this.bookingsStream,
    this.closuresStream,
    this.venuesStream,
  });

  @override
  State<BookingAdminCalendarTab> createState() => _BookingAdminCalendarTabState();
}

class _BookingAdminCalendarTabState extends State<BookingAdminCalendarTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final String _selectedCategory = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final vStream = widget.venuesStream ??
        FirebaseFirestore.instance.collection('booking_venues').snapshots();
    final bStream = widget.bookingsStream ??
        FirebaseFirestore.instance.collection('bookings').snapshots();
    final cStream = widget.closuresStream ??
        FirebaseFirestore.instance.collection('booking_closures').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: vStream,
      builder: (context, vSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: bStream,
          builder: (context, bSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: cStream,
              builder: (context, cSnap) {
                if (vSnap.connectionState == ConnectionState.waiting && !vSnap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold));
                }

                final venues = vSnap.data?.docs.map((d) {
                  final m = d.data();
                  m['_id'] = d.id;
                  return m;
                }).toList() ?? [];

                final bookings = bSnap.data?.docs.map((d) {
                  final m = d.data();
                  m['_id'] = d.id;
                  return m;
                }).toList() ?? [];

                final closures = cSnap.data?.docs.map((d) {
                  final m = d.data();
                  m['_id'] = d.id;
                  return m;
                }).toList() ?? [];

                // أوقات اليوم المختار بتوقيت بغداد (UTC+3) بالمللي ثانية
                final dayStart = DateTime.utc(_selectedDay.year, _selectedDay.month, _selectedDay.day)
                    .subtract(const Duration(hours: 3))
                    .millisecondsSinceEpoch;
                final dayEnd = dayStart + 86400000;

                // فحص التعارضات الدقيقة لليوم المختار (بدون تعارضات وهمية)
                final conflicts = <String, List<String>>{};
                for (final v in venues) {
                  final vId = v['_id'] as String;
                  final vBookings = bookings.where((b) {
                    final bVenue = b['venueId']?.toString();
                    final s = b['status']?.toString();
                    final bStart = (b['start'] as num?)?.toInt() ?? 0;
                    final bEnd = (b['end'] as num?)?.toInt() ?? 0;
                    if (bVenue != vId) return false;
                    if (!['confirmed', 'held', 'payment_review'].contains(s)) return false;
                    return (bStart < dayEnd && bEnd > dayStart);
                  }).toList();

                  final vClosures = closures.where((c) {
                    final cVenue = c['venueId']?.toString();
                    final active = c['active'] == true;
                    final cStart = (c['start'] as num?)?.toInt() ?? 0;
                    final cEnd = (c['end'] as num?)?.toInt() ?? 0;
                    if (cVenue != vId || !active) return false;
                    return (cStart < dayEnd && cEnd > dayStart);
                  }).toList();

                  bool hasConflict = false;
                  String conflictReason = '';

                  // فحص التداخل الزمني المزدوج الفعلي بين الحجوزات
                  for (int i = 0; i < vBookings.length; i++) {
                    for (int j = i + 1; j < vBookings.length; j++) {
                      final s1 = (vBookings[i]['start'] as num?)?.toInt() ?? 0;
                      final e1 = (vBookings[i]['end'] as num?)?.toInt() ?? 0;
                      final s2 = (vBookings[j]['start'] as num?)?.toInt() ?? 0;
                      final e2 = (vBookings[j]['end'] as num?)?.toInt() ?? 0;
                      if (s1 < e2 && e1 > s2) {
                        hasConflict = true;
                        conflictReason = 'تداخل مباشر في أوقات حجزين لنفس المكان';
                        break;
                      }
                    }
                    if (hasConflict) break;
                  }

                  // فحص التداخل الزمني الفعلي بين الحجوزات والإغلاقات
                  if (!hasConflict) {
                    for (final b in vBookings) {
                      final bStart = (b['start'] as num?)?.toInt() ?? 0;
                      final bEnd = (b['end'] as num?)?.toInt() ?? 0;
                      for (final c in vClosures) {
                        final cStart = (c['start'] as num?)?.toInt() ?? 0;
                        final cEnd = (c['end'] as num?)?.toInt() ?? 0;
                        if (bStart < cEnd && bEnd > cStart) {
                          hasConflict = true;
                          conflictReason = 'تعارض بين حجز نشط وإغلاق مسجل في نفس الوقت';
                          break;
                        }
                      }
                      if (hasConflict) break;
                    }
                  }

                  if (hasConflict) {
                    conflicts[vId] = [conflictReason];
                  }
                }

                final filteredVenues = venues.where((v) {
                  if (_selectedCategory != 'all' && v['category'] != _selectedCategory) return false;
                  return true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    // شريط العنوان
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BookingAdminTheme.cardDecoration(context: context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 20, color: BookingAdminTheme.gold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'التقويم المركزي للإشغال وفحص التعارضات',
                                  style: TextStyle(
                                    color: BookingAdminTheme.text(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BookingAdminTheme.gold,
                                  side: const BorderSide(color: BookingAdminTheme.gold),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.date_range_rounded, size: 16),
                                label: Text(
                                  '${_selectedDay.year}/${_selectedDay.month.toString().padLeft(2, '0')}/${_selectedDay.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                                onPressed: _pickCustomDate,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // شريط اختيار الأيام السريع (14 يوماً قادمة)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < 14; i++) ...[
                                  _buildDayChip(DateTime.now().add(Duration(days: i))),
                                ],
                              ],
                            ),
                          ),
                          if (_selectedDay.isAfter(DateTime.now().add(const Duration(days: 14))) ||
                              _selectedDay.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: BookingAdminTheme.goldSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BookingAdminTheme.gold.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: BookingAdminTheme.gold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'معاينة تاريخ مخصص (${_selectedDay.year}/${_selectedDay.month}/${_selectedDay.day}) بتوقيت العراق (UTC+3)',
                                      style: const TextStyle(fontSize: 11, color: BookingAdminTheme.gold, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                    onPressed: () => setState(() => _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
                                    child: const Text('العودة لليوم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BookingAdminTheme.gold, decoration: TextDecoration.underline, fontFamily: 'Cairo')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // تنبيه التعارضات إن وجد
                    if (conflicts.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تم رصد ${conflicts.length} تعارض إشغال في هذا التاريخ! يرجى التدقيق الإداري الفوري.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // دليل الألوان
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot('متاح', Colors.green),
                        const SizedBox(width: 12),
                        _legendDot('مؤكد', BookingAdminTheme.gold),
                        const SizedBox(width: 12),
                        _legendDot('مؤقت / قيد المراجعة', Colors.orange),
                        const SizedBox(width: 12),
                        _legendDot('مغلق', Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // جدول إشغال الأماكن لليوم المختار
                    for (final venue in filteredVenues) ...[
                      _buildVenueOccupancyCard(venue, bookings, closures, dayStart, dayEnd, conflicts.containsKey(venue['_id'])),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BookingAdminTheme.gold,
            onPrimary: Colors.black,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Widget _buildDayChip(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final isSelected = _selectedDay == d;
    final dayNames = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
    final name = dayNames[day.weekday - 1];

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text('$name ${day.day}/${day.month}'),
        selected: isSelected,
        onSelected: (s) {
          if (s) setState(() => _selectedDay = d);
        },
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: isSelected ? BookingAdminTheme.gold : BookingAdminTheme.textMute(context),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(color: isSelected ? BookingAdminTheme.gold : BookingAdminTheme.border(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 10, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildVenueOccupancyCard(
    Map<String, dynamic> venue,
    List<Map<String, dynamic>> allBookings,
    List<Map<String, dynamic>> allClosures,
    int dayStart,
    int dayEnd,
    bool hasConflict,
  ) {
    final vId = venue['_id'] as String;
    final activeBookings = allBookings.where((b) {
      final bVenue = b['venueId']?.toString();
      final bStart = (b['start'] as num?)?.toInt() ?? 0;
      final bEnd = (b['end'] as num?)?.toInt() ?? 0;
      final s = b['status']?.toString();
      return bVenue == vId && (bStart < dayEnd && bEnd > dayStart) && ['confirmed', 'held', 'payment_review'].contains(s);
    }).toList();

    final activeClosures = allClosures.where((c) {
      final cVenue = c['venueId']?.toString();
      final cStart = (c['start'] as num?)?.toInt() ?? 0;
      final cEnd = (c['end'] as num?)?.toInt() ?? 0;
      return cVenue == vId && c['active'] == true && (cStart < dayEnd && cEnd > dayStart);
    }).toList();

    Color statusColor = Colors.green;
    String statusText = 'متاح بالكامل';

    if (hasConflict) {
      statusColor = Colors.redAccent;
      statusText = 'يوجد تعارض إشغال!';
    } else if (activeClosures.isNotEmpty) {
      statusColor = Colors.grey;
      statusText = 'مغلق للصيانة / الإدارة';
    } else if (activeBookings.isNotEmpty) {
      final b = activeBookings.first;
      if (b['status'] == 'confirmed') {
        statusColor = BookingAdminTheme.gold;
        statusText = 'محجوز ومؤكد (${b['customerName'] ?? 'زبون'})';
      } else {
        statusColor = Colors.orangeAccent;
        statusText = 'حجز مؤقت / قيد المراجعة';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BookingAdminTheme.cardDecoration(
        context: context,
        borderColor: hasConflict ? Colors.redAccent : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  venue['name'] ?? 'مكان بدون اسم',
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          if (activeBookings.isNotEmpty || activeClosures.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final b in activeBookings) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• حجز: ${b['customerName']} • الهاتف: ${b['customerPhone'] ?? ''} • الإجمالي: ${b['total']} د.ع',
                        style: TextStyle(color: BookingAdminTheme.textSub(context), fontSize: 11, fontFamily: 'Cairo'),
                      ),
                    ),
                    if (b['customerPhone'] != null && b['customerPhone'].toString().replaceAll(RegExp(r'[^0-9+]'), '').length >= 7)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final clean = b['customerPhone'].toString().replaceAll(RegExp(r'[^0-9+]'), '');
                          final uri = Uri.parse('tel:' + clean);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsetsDirectional.only(start: 4),
                          decoration: BoxDecoration(
                            color: BookingAdminTheme.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, size: 12, color: BookingAdminTheme.gold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            for (final c in activeClosures) ...[
              Text(
                '• إغلاق مسجل: ${c['reason'] ?? 'صيانة'}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontFamily: 'Cairo'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
