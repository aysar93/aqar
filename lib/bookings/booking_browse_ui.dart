import 'booking_page_indicator.dart';
import 'booking_pricing_draft.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'booking_widgets.dart';

String bookingPriceUnit(Map<String, dynamic> venue) =>
    BookingPricingDraft.fromVenue(venue) != null ||
            venue['pricingMode'] == 'shifts'
        ? 'للفترة'
        : venue['pricingMode'] == 'hourly'
            ? 'للساعة'
            : 'للحجز';

/// Rectangular container header for booking sections (inspired by Anbar Real
/// Estate property section headers) with title, actual count, and "عرض الكل".
class BookingSectionHeader extends StatelessWidget {
  const BookingSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.onSeeAll,
  });
  final String title;
  final int count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      key: ValueKey('booking-section-header-$title'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: bookingGold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : bookingNavy,
              ),
            ),
          ),
          if (onSeeAll != null) ...[
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: dark ? bookingGold : bookingNavy,
              ),
              onPressed: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_left, size: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Public venue presentation only. Authorization and filtering stay with the
/// existing verified snapshot in BookingScreen. No invented featured/date fields.
class BookingBrowseContent extends StatelessWidget {
  const BookingBrowseContent(
      {super.key,
      required this.venues,
      required this.onOpen,
      this.featuredVenues = const [],
      this.featuredPreview = false,
      this.hasMore = false,
      this.loading = false,
      this.onLoadMore});
  final List<Map<String, dynamic>> venues, featuredVenues;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final bool hasMore, loading;
  final bool featuredPreview;
  final VoidCallback? onLoadMore;
  Widget section(BuildContext context, String title,
          List<Map<String, dynamic>> items, String empty) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cardBg = dark ? const Color(0xFF1E2638) : Colors.white;
    final borderColor = dark
        ? bookingGold.withValues(alpha: .28)
        : const Color(0xFFE2E8F0);

    return Container(
      key: ValueKey('booking-unified-section-$title'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: BookingSectionHeader(
              title: title,
              count: items.length,
              onSeeAll: items.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BookingScaffold(
                              appBar: AppBar(title: Text(title)),
                              body: ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (_, i) => BookingVenueCard(
                                      venue: items[i],
                                      onTap: () => onOpen(items[i])))))),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(empty,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45))))
          else
            BookingVenueRail(
                key: ValueKey(title),
                venues: items,
                onOpen: onOpen,
                featured: title == 'المميزة'),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (featuredPreview)
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text('المميزة — بيانات معاينة محلية فقط',
                  style: TextStyle(fontSize: 12))),
        section(context, 'المميزة', featuredVenues,
            'لا توجد أماكن ذات تمييز معتمد حاليًا.'),
        section(context, 'استكشف الأماكن', venues,
            'لا توجد أماكن مطابقة ضمن الدفعة المحمّلة؛ جرّب الفلاتر أو حمّل المزيد.'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
                'البحث والترتيب ضمن الأماكن المحمّلة؛ تحميل المزيد يحتفظ بالفلاتر.',
                style: TextStyle(fontSize: 12))),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (hasMore)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              child: OutlinedButton.icon(
                  onPressed: loading ? null : onLoadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('عرض المزيد'))),
      ]);
}

class BookingVenueRail extends StatefulWidget {
  const BookingVenueRail(
      {super.key,
      required this.venues,
      required this.onOpen,
      this.featured = false});
  final bool featured;
  final List<Map<String, dynamic>> venues;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<BookingVenueRail> createState() => _BookingVenueRailState();
}

class _BookingVenueRailState extends State<BookingVenueRail> {
  PageController? controller;
  int page = 0, perPage = 0;
  double fraction = 0;
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  double height(BuildContext context, double width) {
    final calculated = widget.venues.fold<double>(
        0, (h, v) => math.max(h, bookingCompactCardHeight(context, v, width)));
    return math.max(336.0, calculated);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        if (widget.venues.isEmpty) return const SizedBox.shrink();
        final count = math.max(1, (bounds.maxWidth / 340).floor());
        final f = count == 1 ? 0.88 : 1.0;
        final pages = (widget.venues.length / count).ceil();
        if (controller == null || perPage != count || fraction != f) {
          final old = controller;
          perPage = count;
          fraction = f;
          page = page.clamp(0, pages - 1);
          controller = PageController(viewportFraction: f, initialPage: page);
          if (old != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          }
        }
        if (page >= pages) {
          page = pages - 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && controller!.hasClients) controller!.jumpToPage(page);
          });
        }
        final cardWidth = bounds.maxWidth * f / count - 16;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: height(context, cardWidth),
              child: PageView.builder(
                  padEnds: false,
                  key: PageStorageKey<Object>(
                      widget.key ?? 'booking-venues-horizontal'),
                  controller: controller,
                  itemCount: pages,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (_, p) => Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = p * count;
                                i <
                                    math.min(
                                        (p + 1) * count, widget.venues.length);
                                i++)
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: BookingVenueCard(
                                          compact: true,
                                          featured: widget.featured,
                                          venue: widget.venues[i],
                                          onTap: () => widget
                                              .onOpen(widget.venues[i])))),
                            for (var i = math.min(
                                    (p + 1) * count, widget.venues.length);
                                i < (p + 1) * count;
                                i++)
                              const Spacer(),
                          ]))),
          BookingPageIndicator(
              count: pages,
              page: page,
              onPage: (i) => controller!.animateToPage(i,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOut)),
        ]);
      });
}

class BookingRecordCard extends StatelessWidget {
  const BookingRecordCard(
      {super.key, required this.booking, required this.onTap});
  final Map<String, dynamic> booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${booking['venueName'] ?? 'تفاصيل الحجز'}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      Chip(
                          avatar: const Icon(Icons.event_note, size: 18),
                          label: Text(bookingStatusNames[booking['status']] ??
                              'حالة غير معروفة'))
                    ]),
                    if (booking['start'] is num)
                      Text(bookingVisitTime(DateTime.fromMillisecondsSinceEpoch(
                              (booking['start'] as num).toInt(),
                              isUtc: true)
                          .add(const Duration(hours: 3)))),
                    const Divider(height: 24),
                    Wrap(spacing: 20, runSpacing: 8, children: [
                      Text('الإجمالي ${bookingMoney(booking['total'])}'),
                      Text('العربون ${bookingMoney(booking['deposit'])}')
                    ]),
                    const SizedBox(height: 10),
                    const Row(children: [
                      Expanded(
                          child: Text('عرض تفاصيل الحجز',
                              style: TextStyle(fontWeight: FontWeight.w700))),
                      Icon(Icons.chevron_left, color: bookingGold)
                    ]),
                  ]))));
}

class BookingBrowseHeader extends StatelessWidget {
  const BookingBrowseHeader({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مكان يليق بمناسبتك',
            style: TextStyle(
                fontSize: 26, height: 1.6, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('شاليهات وقاعات ومزارع في الأنبار',
            style: TextStyle(
                fontSize: 14,
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);
}
