import 'package:flutter/material.dart';

/// A single accessible layout for waiting, empty and connection states.
class BookingStateView extends StatelessWidget {
  const BookingStateView({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.cloud_off_outlined,
    this.action,
    this.onRetry,
    this.busy = false,
  });

  final String title, detail;
  final IconData icon;
  final bool busy;
  final Widget? action;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 40, color: const Color(0xFFC5A16B)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.8),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ] else if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A16B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('إعادة المحاولة',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      );
}
