import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/widgets/banner_slider.dart';

void main() {
  testWidgets(
      'banner metadata survives a stream failure and recovers without reopening',
      (tester) async {
    final stream = StreamController<List<BannerModel>>();
    BannerModel banner(String title) => BannerModel(
        id: title,
        title: title,
        subtitle: '',
        imageUrl: 'https://synthetic.invalid/$title.png',
        type: 'external',
        targetId: '',
        isActive: true,
        order: 0);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BannerSlider(stream: stream.stream))));
    stream.add([banner('before')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('before'), findsOneWidget);
    stream.addError(StateError('synthetic network interruption'));
    await tester.pump();
    expect(find.text('before'), findsOneWidget);
    stream.add([banner('after')]);
    await tester.pump();
    expect(find.text('after'), findsOneWidget);
    expect(find.text('before'), findsNothing);
    stream.add([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('after'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(stream.close());
    await tester.pump();
  });
}
