import 'package:aqar/services/share_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(402, 874), const Size(1032, 1376)]) {
    testWidgets('Share origin stays inside a $size viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late BuildContext anchor;
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Center(child: SizedBox(width: 48, height: 48,
          child: Builder(builder: (context) {
            anchor = context;
            return const SizedBox.expand();
          }),
        )),
      )));
      final origin = shareOrigin(anchor);
      expect(origin.width, greaterThan(0));
      expect(origin.height, greaterThan(0));
      expect((Offset.zero & size).contains(origin.topLeft), isTrue);
      expect((Offset.zero & size).contains(origin.bottomRight), isTrue);
    });
  }

  testWidgets('An offscreen caller uses a visible fallback', (tester) async {
    late BuildContext anchor;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Transform.translate(
      offset: const Offset(-10000, 0),
      child: Builder(builder: (context) {
        anchor = context;
        return const SizedBox(width: 48, height: 48);
      }),
    ))));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(shareOrigin(anchor).center, (Offset.zero & size).center);
  });
}
