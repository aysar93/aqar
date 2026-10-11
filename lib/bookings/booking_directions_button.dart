import 'package:flutter/material.dart';
import 'booking_location.dart';

class BookingDirectionsButton extends StatelessWidget {
  final Map<String, dynamic> venue;
  const BookingDirectionsButton({super.key, required this.venue});
  @override
  Widget build(BuildContext context) {
    final point = bookingCoordinates(venue);
    if (point == null) {
      return const Text('إحداثيات المكان غير متاحة للاتجاهات.');
    }
    return OutlinedButton.icon(
        icon: const Icon(Icons.directions),
        label: const Text('الاتجاهات'),
        onPressed: () async {
          final opened = await bookingOpenDirections(point);
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'تعذر فتح الخرائط. تحقق من وجود تطبيق خرائط أو اتصال الإنترنت.')));
          }
        });
  }
}
