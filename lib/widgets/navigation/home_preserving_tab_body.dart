import 'package:flutter/material.dart';

/// Retains Home while other tabs keep their existing mount/dispose lifecycle.
/// In particular, hidden reels must not be initialized or left playing.
class HomePreservingTabBody extends StatelessWidget {
  const HomePreservingTabBody({
    super.key,
    required this.currentIndex,
    required this.pages,
  });

  final int currentIndex;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: currentIndex != 0,
            child: TickerMode(enabled: currentIndex == 0, child: pages.first),
          ),
          if (currentIndex != 0)
            KeyedSubtree(
                key: ValueKey(currentIndex), child: pages[currentIndex]),
        ],
      );
}
