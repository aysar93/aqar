import 'package:flutter/material.dart';

/// Retains a visited, finite home section while the lazy list scrolls past it.
/// Its stream keeps receiving updates, including immediate block removals.
class KeepAliveSection extends StatefulWidget {
  const KeepAliveSection({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveSection> createState() => _KeepAliveSectionState();
}

class _KeepAliveSectionState extends State<KeepAliveSection>
    with AutomaticKeepAliveClientMixin<KeepAliveSection> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
