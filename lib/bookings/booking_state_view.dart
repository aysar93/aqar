import 'package:flutter/material.dart';

/// A single accessible layout for waiting, empty and connection states.
class BookingStateView extends StatelessWidget {
  const BookingStateView(
      {super.key,
      required this.title,
      required this.detail,
      this.icon = Icons.cloud_off_outlined,
      this.busy = false});
  final String title, detail;
  final IconData icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 40, color: const Color(0xFFB8943B)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.8)),
          ])));
}
