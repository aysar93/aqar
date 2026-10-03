import 'package:aqar/screens/admin/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [150.0, 175.0, 210.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final status in ['pending', 'approved', 'rejected']) {
        testWidgets('status $status fits width $width at scale $scale',
            (tester) async {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SizedBox(
                      width: width,
                      child: Row(children: [
                        Flexible(child: StatusChip(status: status)),
                        const SizedBox(width: 3),
                        const Flexible(
                          child: StatusChip(
                              status: 'available', availability: true),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
