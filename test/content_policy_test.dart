import 'package:aqar/moderation/content_policy.dart';
import 'package:aqar/moderation/eula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic normalization and English case cannot bypass the text guard',
      () {
    for (final text in ['PORN', 'إبَاحي', 'شـرموط', 'fUcK']) {
      expect(ContentPolicy.rejects(text), isTrue);
    }
    expect(
        ContentPolicy.rejects('بيت للبيع في الرمادي، مساحة 200 متر'), isFalse);
    expect(ContentPolicy.rejects('x' * 10001), isTrue);
  });
  testWidgets('EULA consent starts unchecked and requires an explicit tap',
      (tester) async {
    bool accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: StatefulBuilder(
          builder: (context, setState) => EulaConsent(
                accepted: accepted,
                onChanged: (v) => setState(() => accepted = v),
              )),
    ))));
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(find.textContaining('لا نتسامح مطلقاً'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(accepted, isTrue);
  });
}
