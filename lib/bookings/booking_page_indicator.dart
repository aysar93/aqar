import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BookingPageIndicator extends StatefulWidget {
  const BookingPageIndicator(
      {super.key,
      required this.count,
      required this.page,
      required this.onPage,
      this.accent = const Color(0xFFC5A16B)});
  final int count, page;
  final ValueChanged<int> onPage;
  final Color accent;
  @override
  State<BookingPageIndicator> createState() => _BookingPageIndicatorState();
}

class _BookingPageIndicatorState extends State<BookingPageIndicator> {
  bool focused = false;
  void go(int page) => widget.onPage(page.clamp(0, widget.count - 1));
  @override
  Widget build(BuildContext context) {
    if (widget.count <= 1) return const SizedBox.shrink();
    final current = widget.page.clamp(0, widget.count - 1),
        visible = math.min(widget.count, 7),
        start = (current - visible ~/ 2).clamp(0, widget.count - visible);
    return Center(
        child: CallbackShortcuts(
            bindings: {
          SingleActivator(LogicalKeyboardKey.arrowLeft): () => go(current + 1),
          SingleActivator(LogicalKeyboardKey.arrowRight): () => go(current - 1),
          SingleActivator(LogicalKeyboardKey.home): () => go(0),
          SingleActivator(LogicalKeyboardKey.end): () => go(widget.count - 1)
        },
            child: FocusableActionDetector(
                onShowFocusHighlight: (v) => setState(() => focused = v),
                child: Semantics(
                    label: 'مؤشر الصفحات، اسحب للتنقل',
                    value: '${current + 1} من ${widget.count}',
                    increasedValue: current < widget.count - 1
                        ? '${current + 2} من ${widget.count}'
                        : null,
                    decreasedValue:
                        current > 0 ? '$current من ${widget.count}' : null,
                    onIncrease: current < widget.count - 1
                        ? () => go(current + 1)
                        : null,
                    onDecrease: current > 0 ? () => go(current - 1) : null,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final x =
                              Directionality.of(context) == TextDirection.rtl
                                  ? (visible * 14 + 12 - d.localPosition.dx)
                                  : d.localPosition.dx;
                          go(start +
                              ((x - 6) / 14).floor().clamp(0, visible - 1));
                        },
                        child: Container(
                            height: 24,
                            width: visible * 14 + 12,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                border: focused
                                    ? Border.all(color: widget.accent)
                                    : null,
                                borderRadius: BorderRadius.circular(12)),
                            child: ExcludeSemantics(
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  for (var i = start; i < start + visible; i++)
                                    AnimatedContainer(
                                        duration: MediaQuery
                                                .disableAnimationsOf(context)
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        width: i == current ? 18 : 6,
                                        height: 5,
                                        decoration: BoxDecoration(
                                            color: i == current
                                                ? widget.accent
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: .42),
                                            borderRadius:
                                                BorderRadius.circular(6)))
                                ]))))))));
  }
}
