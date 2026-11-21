import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Rejection reason card is displayed when status is rejected', (tester) async {
    final booking = {
      'status': 'rejected',
      'reason': 'المكان تحت الصيانة الطارئة في هذا الموعد',
      'ownerId': 'owner_123',
      'customerId': 'cust_456',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              if (booking['status'] == 'rejected') ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('rejection-reason-container'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سبب رفض الحجز من قبل المالك:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (booking['reason'] ?? booking['rejectionReason'] ?? 'لم يحدد المالك سبباً إضافياً').toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('rejection-reason-container')), findsOneWidget);
    expect(find.text('سبب رفض الحجز من قبل المالك:'), findsOneWidget);
    expect(find.text('المكان تحت الصيانة الطارئة في هذا الموعد'), findsOneWidget);
  });

  testWidgets('Cancellation card is displayed when status is cancelled', (tester) async {
    final booking = {
      'status': 'cancelled',
      'cancelledBy': 'cust_456',
      'customerId': 'cust_456',
      'cancellationReason': 'ظروف خاصة طارئة للضيف',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              if (booking['status'] == 'cancelled' || booking['cancelledBy'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('cancellation-reason-container'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF475569), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'حالة الإلغاء: ${booking['cancelledBy'] == booking['customerId'] ? 'أُلغي بواسطة الزبون' : (booking['cancelledBy'] == booking['ownerId'] ? 'أُلغي بواسطة المالك' : (booking['cancelledBy'] ?? 'ملغى'))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Color(0xFF334155),
                              ),
                            ),
                            if (booking['cancellationReason'] != null || booking['reason'] != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                'السبب: ${booking['cancellationReason'] ?? booking['reason']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('cancellation-reason-container')), findsOneWidget);
    expect(find.text('حالة الإلغاء: أُلغي بواسطة الزبون'), findsOneWidget);
    expect(find.text('السبب: ظروف خاصة طارئة للضيف'), findsOneWidget);
  });
}
