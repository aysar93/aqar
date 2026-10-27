import 'package:flutter/material.dart';
import '../bookings/booking_notification.dart';

/// Presents only readable booking updates, scoped to the current auth session.
class BookingForegroundNotice {
  BookingForegroundNotice({
    required this.navigatorKey,
    required this.currentUserId,
    required this.canReadBooking,
    required this.openBooking,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String? Function() currentUserId;
  final Future<bool> Function(String bookingId) canReadBooking;
  final Future<void> Function(Map<String, dynamic> payload) openBooking;

  Future<void> receive(Map<String, dynamic> payload) async {
    final bookingId = bookingNotificationId(payload);
    final userId = currentUserId();
    if (bookingId == null || userId == null) return;
    final data = Map<String, dynamic>.from(payload);
    try {
      if (!await canReadBooking(bookingId) || currentUserId() != userId) return;
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(SnackBar(
        content: const Text('لديك تحديث في حجز'),
        action: SnackBarAction(
          label: 'عرض الحجز',
          onPressed: () async {
            try {
              if (currentUserId() != userId ||
                  !await canReadBooking(bookingId) ||
                  currentUserId() != userId) {
                return;
              }
              await openBooking(data);
            } catch (_) {
              // Permission changes and offline reads must not open stale data.
            }
          },
        ),
      ));
    } catch (_) {
      // Do not display private notification content when access is unverified.
    }
  }
}
