import 'package:aqar/bookings/booking_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support response survives closing a focused text field',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                        context: context,
                        builder: (_) => const BookingSupportResponseDialog());
                  },
                  child: const Text('Open'),
                ),
              )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Synthetic support response');
    await tester.tap(find.text('إرسال'));
    await tester.pump();
    expect(result, 'Synthetic support response');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(BookingSupportResponseDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
