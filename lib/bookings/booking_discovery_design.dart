import '../screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _navy = Color(0xFF0F172A), _gold = Color(0xFFC5A16B);

/// The search field and greeting share one surface; categories live outside it.
class BookingWelcomeSearch extends StatelessWidget {
  const BookingWelcomeSearch(
      {super.key,
      required this.search,
      this.toolbarAction,
      this.filterBar});
  final Widget search;
  final Widget? toolbarAction;
  final Widget? filterBar;
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light),
        child: LayoutBuilder(builder: (context, bounds) {
          final radius = (bounds.maxWidth * .09).clamp(28.0, 42.0);
          return Container(
              key: const ValueKey('booking-welcome-search'),
              width: double.infinity,
              padding:
                  EdgeInsetsDirectional.fromSTEB(20, topInset + 18, 20, 20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFD8BD95), Color(0xFFC5A16B)]),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(radius),
                      bottomRight: Radius.circular(radius))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (Navigator.of(context).canPop()) ...[
                            IconButton(
                              tooltip: 'الرجوع للرئيسية',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A).withValues(alpha: .10),
                                foregroundColor: _navy,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('مكان يليق بك',
                                    style: TextStyle(
                                        fontSize: 27,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                        color: _navy)),
                                SizedBox(height: 6),
                                Text('شاليهات وقاعات ومزارع في الأنبار',
                                    style: TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: Color(0xFF354157)))
                              ])),
                          IconButton(
                            tooltip: 'الإشعارات',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A).withValues(alpha: .10),
                              foregroundColor: _navy,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            ),
                            icon: const Icon(Icons.notifications_none_rounded, size: 22),
                          ),
                          if (toolbarAction != null) ...[
                            const SizedBox(width: 8),
                            toolbarAction!
                          ]
                        ]),
                    const SizedBox(height: 16),
                    Theme(
                        data: Theme.of(context).copyWith(
                            textTheme: Theme.of(context)
                                .textTheme
                                .apply(bodyColor: _navy),
                            iconTheme: const IconThemeData(color: _navy),
                            inputDecorationTheme: InputDecorationTheme(
                                filled: true,
                                fillColor: Colors.white,
                                hintStyle: const TextStyle(
                                    color: Color(0xFF55647A), fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                        const BorderSide(color: _navy)))),
                        child: search),
                    if (filterBar != null) ...[
                      const SizedBox(height: 10),
                      filterBar!
                    ]
                  ]));
        }));
  }
}

const bookingCategories = {
  '': 'الكل',
  'chalet': 'شاليه',
  'farm': 'مزرعة',
  'hall': 'قاعة'
};

class BookingCategoryStrip extends StatelessWidget {
  const BookingCategoryStrip(
      {super.key, required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
        key: const PageStorageKey('booking-category-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in bookingCategories.entries)
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Semantics(
                    selected: selected == e.key,
                    button: true,
                    label: e.value,
                    child: InkWell(
                        key: ValueKey('booking-category-${e.key}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelected(e.key),
                        child: SizedBox(
                            width: 68,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                      duration: MediaQuery
                                              .disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 160),
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                          color: selected == e.key
                                              ? (dark
                                                  ? const Color(0xFF303343)
                                                  : const Color(0xFFF0E7D8))
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          border: Border.all(
                                              color: selected == e.key
                                                  ? _gold
                                                  : (dark
                                                      ? Colors.white12
                                                      : const Color(
                                                          0xFFE2E8F0)),
                                              width: selected == e.key
                                                  ? 1.4
                                                  : 1.0),
                                          boxShadow: !dark
                                              ? [
                                                  BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: .035),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2))
                                                ]
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: Center(
                                          child: CustomPaint(
                                              size: const Size(22, 22),
                                              painter: BookingCategoryPainter(
                                                  e.key,
                                                  selected == e.key
                                                      ? _gold
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface)))),
                                  const SizedBox(height: 5),
                                  Text(e.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.2,
                                          fontWeight: selected == e.key
                                              ? FontWeight.w700
                                              : FontWeight.w600)),
                                  const SizedBox(height: 4),
                                ])))))
        ]));
  }
}

/// Four vector glyphs sharing a 32-unit grid and one stroke weight.
class BookingCategoryPainter extends CustomPainter {
  const BookingCategoryPainter(this.category, this.color);
  final String category;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 32, s.height / 32);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (category.isEmpty) {
      for (final x in [3.0, 18.0])
        for (final y in [3.0, 18.0])
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x, y, 11, 11), const Radius.circular(2)),
              p);
    } else if (category == 'chalet') {
      c.drawPath(
          Path()
            ..moveTo(3, 14)
            ..lineTo(3, 9)
            ..lineTo(18, 4)
            ..lineTo(27, 9)
            ..lineTo(27, 23)
            ..lineTo(4, 23)
            ..lineTo(4, 14)
            ..lineTo(28, 14)
            ..moveTo(16, 14)
            ..lineTo(16, 23)
            ..moveTo(22, 14)
            ..lineTo(22, 23)
            ..moveTo(8, 17)
            ..lineTo(12, 17)
            ..lineTo(12, 20)
            ..lineTo(8, 20)
            ..close(),
          p);
      c.drawLine(const Offset(2, 27), const Offset(27, 27), p);
      c.drawPath(
          Path()
            ..moveTo(3, 30)
            ..quadraticBezierTo(7, 28, 11, 30)
            ..quadraticBezierTo(15, 32, 19, 30)
            ..quadraticBezierTo(23, 28, 27, 30),
          p);
    } else if (category == 'hall') {
      c.drawPath(
          Path()
            ..moveTo(3, 11)
            ..lineTo(16, 4)
            ..lineTo(29, 11)
            ..close()
            ..moveTo(4, 28)
            ..lineTo(28, 28)
            ..moveTo(7, 13)
            ..lineTo(7, 25)
            ..moveTo(13, 13)
            ..lineTo(13, 25)
            ..moveTo(19, 13)
            ..lineTo(19, 25)
            ..moveTo(25, 13)
            ..lineTo(25, 25),
          p);
    } else {
      c.drawPath(
          Path()
            ..moveTo(5, 25)
            ..lineTo(5, 15)
            ..lineTo(12, 9)
            ..lineTo(19, 15)
            ..lineTo(19, 25)
            ..close()
            ..moveTo(12, 25)
            ..lineTo(12, 19)
            ..moveTo(25, 25)
            ..lineTo(25, 10)
            ..moveTo(25, 15)
            ..cubicTo(16, 12, 21, 4, 25, 4)
            ..cubicTo(31, 4, 34, 12, 25, 15)
            ..moveTo(2, 29)
            ..lineTo(30, 29),
          p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant BookingCategoryPainter old) =>
      old.category != category || old.color != color;
}
