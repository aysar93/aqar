import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'booking_widgets.dart';

const bookingTaskCollections = {
  'requests': 'bookings',
  'media': 'booking_media_reviews',
  'proofs': 'booking_ownership_proofs',
  'reviews': 'booking_reviews',
  'reports': 'booking_reports'
};

class BookingAdminTasks extends StatelessWidget {
  const BookingAdminTasks({super.key, this.records, required this.onOpen});
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>? records;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ما الذي يحتاج قرارك؟',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('مهام تنتظر المراجعة، من بيانات الخادم الحالية.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, bounds) {
          final cols = bounds.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5
              ? 1
              : 2;
          final width = (bounds.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final item in const {
              'requests': 'طلبات الحجز',
              'media': 'وسائط بانتظار المراجعة',
              'proofs': 'إثباتات الملكية',
              'reviews': 'تقييمات معلقة',
              'reports': 'بلاغات مفتوحة'
            }.entries)
              SizedBox(
                  width: width,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: records != null
                          ? records![item.key]
                          : FirebaseFirestore.instance
                              .collection(bookingTaskCollections[item.key]!)
                              .where('status',
                                  isEqualTo: item.key == 'requests'
                                      ? 'requested'
                                      : item.key == 'reports'
                                          ? 'open'
                                          : 'pending')
                              .snapshots(includeMetadataChanges: true),
                      builder: (context, s) {
                        final verified = s.hasData &&
                            !s.hasError &&
                            !s.data!.metadata.isFromCache &&
                            !s.data!.metadata.hasPendingWrites;
                        return Card(
                            margin: EdgeInsets.zero,
                            child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => onOpen(item.key),
                                child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                              Icons.pending_actions_outlined,
                                              color: bookingGold),
                                          const SizedBox(height: 12),
                                          Text(item.value,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(
                                              verified
                                                  ? (s.data!.docs.isEmpty
                                                      ? 'لا مهام معلقة'
                                                      : '${s.data!.docs.length}')
                                                  : 'غير متاح',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700)),
                                          if (!verified)
                                            const Text(
                                                'يلزم اتصال وتحقق من الصلاحية',
                                                style: TextStyle(fontSize: 12)),
                                        ]))));
                      }))
          ]);
        }),
      ]));
}
