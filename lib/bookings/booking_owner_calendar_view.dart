import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingOwnerCalendarView extends StatefulWidget {
  final String ownerId;
  final List<Map<String, dynamic>> venues;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;
  final List<Map<String, dynamic>>? initialBookingsForTest;

  const BookingOwnerCalendarView({
    super.key,
    required this.ownerId,
    required this.venues,
    this.bookingsStream,
    this.initialBookingsForTest,
  });

  @override
  State<BookingOwnerCalendarView> createState() => _BookingOwnerCalendarViewState();
}

class _BookingOwnerCalendarViewState extends State<BookingOwnerCalendarView> {
  late DateTime _month;
  String? _selectedVenueId;

  static const List<String> monthNames = [
    'يناير / كانون الثاني',
    'فبراير / شباط',
    'مارس / آذار',
    'أبريل / نيسان',
    'مايو / أيار',
    'يونيو / حزيران',
    'يوليو / تموز',
    'أغسطس / آب',
    'سبتمبر / أيلول',
    'أكتوبر / تشرين الأول',
    'نوفمبر / تشرين الثاني',
    'ديسمبر / كانون الأول',
  ];

  @override
  void initState() {
    super.initState();
    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    _month = DateTime(nowBaghdad.year, nowBaghdad.month);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Days in current selected month
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month, daysInMonth, 23, 59, 59);

    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    final isCurrentMonth = _month.year == nowBaghdad.year && _month.month == nowBaghdad.month;

    final displayedVenues = _selectedVenueId == null
        ? widget.venues
        : widget.venues.where((v) => v['id'] == _selectedVenueId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Month Selector & Venue Filter Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'الشهر السابق',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _month = DateTime(_month.year, _month.month - 1);
                      });
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showMonthPicker(context);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month, color: bookingGold, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${monthNames[_month.month - 1]} ${_month.year}',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: bookingGold, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'الشهر التالي',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _month = DateTime(_month.year, _month.month + 1);
                      });
                    },
                  ),
                ],
              ),

              // Venue Filter Chips (if owner has multiple venues)
              if (widget.venues.length > 1) ...[
                const Divider(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('جميع الأماكن'),
                        selected: _selectedVenueId == null,
                        selectedColor: bookingGold.withValues(alpha: 0.2),
                        checkmarkColor: bookingGold,
                        onSelected: (_) => setState(() => _selectedVenueId = null),
                      ),
                      const SizedBox(width: 6),
                      for (final v in widget.venues) ...[
                        FilterChip(
                          label: Text('${v['name'] ?? 'مكان'}'),
                          selected: _selectedVenueId == v['id'],
                          selectedColor: bookingGold.withValues(alpha: 0.2),
                          checkmarkColor: bookingGold,
                          onSelected: (_) => setState(() => _selectedVenueId = v['id']),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Legend
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: BookingStatusLegend(),
        ),
        const SizedBox(height: 6),

        // 3. Gantt-like Multi-Day Matrix (Stream of Owner's Bookings)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.bookingsStream ??
              (widget.initialBookingsForTest != null
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('bookings')
                      .where('ownerId', isEqualTo: widget.ownerId)
                      .snapshots()),
          builder: (context, snapshot) {
            if (widget.initialBookingsForTest == null && snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: bookingGold),
                ),
              );
            }

            final allBookings = widget.initialBookingsForTest ??
                snapshot.data?.docs.map((d) => <String, dynamic>{
                      ...d.data(),
                      'id': d.id,
                    }).toList() ??
                [];

            // Filter bookings that overlap with selected month
            final monthStartMs = monthStart.millisecondsSinceEpoch;
            final monthEndMs = monthEnd.millisecondsSinceEpoch;
            final activeBookings = allBookings.where((b) {
              final start = (b['start'] as num?)?.toInt() ?? 0;
              final end = (b['end'] as num?)?.toInt() ?? 0;
              return start <= monthEndMs && end >= monthStartMs;
            }).toList();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Days Header Row
                      Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        child: Row(
                          children: [
                            Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              alignment: Alignment.centerRight,
                              child: const Text(
                                'المكان / الأيام',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            for (var day = 1; day <= daysInMonth; day++) ...[
                              Builder(builder: (context) {
                                final isToday = isCurrentMonth && day == nowBaghdad.day;
                                final dayDate = DateTime(_month.year, _month.month, day);
                                const weekdaysArabic = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
                                final wd = weekdaysArabic[dayDate.weekday - 1];
                                return Container(
                                  width: 48,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? bookingGold.withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    border: isToday
                                        ? const Border(
                                            bottom: BorderSide(color: bookingGold, width: 2))
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          wd,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'Cairo',
                                            color: isToday ? bookingGold : Colors.grey,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '$day',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Cairo',
                                            fontWeight:
                                                isToday ? FontWeight.bold : FontWeight.w600,
                                            color: isToday ? bookingGold : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Venue Rows
                      for (final venue in displayedVenues) ...[
                        Row(
                          children: [
                            // Venue Label Cell
                            Container(
                              width: 170,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${venue['name'] ?? 'مكان'}',
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                  Text(
                                    '${venue['location'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            // Day Cells
                            for (var day = 1; day <= daysInMonth; day++) ...[
                              Builder(builder: (context) {
                                final isToday = isCurrentMonth && day == nowBaghdad.day;
                                final dayStart = DateTime(_month.year, _month.month, day);
                                final dayEnd =
                                    DateTime(_month.year, _month.month, day, 23, 59, 59);

                                final dayBookings = activeBookings.where((b) {
                                  if (b['venueId'] != venue['id']) return false;
                                  final bStart = (b['start'] as num?)?.toInt() ?? 0;
                                  final bEnd = (b['end'] as num?)?.toInt() ?? 0;
                                  return bStart <= dayEnd.millisecondsSinceEpoch &&
                                      bEnd >= dayStart.millisecondsSinceEpoch;
                                }).toList();

                                return Container(
                                  width: 48,
                                  height: 56,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? bookingGold.withValues(alpha: 0.05)
                                        : Colors.transparent,
                                    border: Border(
                                      left: BorderSide(
                                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                        width: 1,
                                      ),
                                      bottom: BorderSide(
                                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: dayBookings.isEmpty
                                      ? null
                                      : Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                              for (final bk in dayBookings.take(2)) ...[
                                                Builder(builder: (context) {
                                                  final visual = BookingShiftVisual.resolve(bk['pricing']);
                                                  final badgeColor = bk['status'] == 'confirmed'
                                                      ? visual.accentColor
                                                      : _statusColor(bk['status']);
                                                  return InkWell(
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => BookingDetailsScreen(
                                                            bookingId: bk['id'] as String,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 2),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 3, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: badgeColor,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              visual.icon,
                                                              size: 9,
                                                              color: Colors.white,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              _shiftShort(bk['pricing']),
                                                              style: const TextStyle(
                                                                fontSize: 8,
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontFamily: 'Cairo',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            if (dayBookings.length > 2)
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '+${dayBookings.length - 2}',
                                                  style: const TextStyle(
                                                    fontSize: 7.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: bookingGold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                            ),
                                          ),
                                        );
                              }),
                            ],
                          ],
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _statusColor(dynamic status) {
    switch (status) {
      case 'confirmed':
      case 'arrived':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'requested':
      case 'held':
      case 'payment_review':
        return bookingGold;
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _shiftShort(dynamic pricing) {
    final kind = BookingShiftVisual.resolve(pricing).kind;
    return switch (kind) {
      BookingShiftKind.morning => 'ص',
      BookingShiftKind.evening => 'م',
      BookingShiftKind.fullDay => 'ك',
      BookingShiftKind.other => 'ح',
    };
  }

  void _showMonthPicker(BuildContext context) {
    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    final months = <DateTime>[];
    for (var i = -2; i < 10; i++) {
      months.add(DateTime(nowBaghdad.year, nowBaghdad.month + i));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر الشهر لعرض جدول الحجوزات',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: months.length,
                      itemBuilder: (_, i) {
                        final m = months[i];
                        final isSel = m.year == _month.year && m.month == _month.month;
                        return ListTile(
                          dense: true,
                          selected: isSel,
                          leading: Icon(
                            isSel ? Icons.check_circle : Icons.calendar_today_outlined,
                            color: isSel ? bookingGold : Colors.grey,
                          ),
                          title: Text(
                            '${monthNames[m.month - 1]} ${m.year}',
                            style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo'),
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            setState(() => _month = m);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
