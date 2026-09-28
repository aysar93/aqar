import 'dart:async';
import 'package:aqar/models/property_model.dart';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/widgets/banner_slider.dart';
import 'package:aqar/screens/login_screen.dart';
import 'package:aqar/screens/register_screen.dart';
import 'package:aqar/widgets/home/horizontal_properties_section.dart';
import 'package:aqar/widgets/home/why_aqar_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Missing and invalid banners leave no reserved space',
      (tester) async {
    final stream = StreamController<List<BannerModel>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      BannerSlider(stream: stream.stream),
      const Text('after banner'),
    ]))));
    expect(tester.getTopLeft(find.text('after banner')).dy, 0);
    stream.add([
      BannerModel(
          id: 'invalid',
          title: '',
          subtitle: '',
          imageUrl: '',
          type: 'external',
          targetId: '',
          isActive: true,
          order: 0)
    ]);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('after banner')).dy, 0);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('after banner')).dy, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Empty, loading and failed property sections reserve no height',
      (tester) async {
    final stream = StreamController<List<PropertyModel>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      HorizontalPropertiesSection(
          title: 'أحدث العقارات', stream: stream.stream),
      const Text('next section'),
    ]))));
    expect(tester.getTopLeft(find.text('next section')).dy, 0);
    stream.add([]);
    await tester.pump();
    expect(tester.getTopLeft(find.text('next section')).dy, 0);
    stream.addError(StateError('offline'));
    await tester.pump();
    expect(tester.getTopLeft(find.text('next section')).dy, 0);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('Login and registration remain scrollable at width $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('شروط الاستخدام'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget); // Remember me only.
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();
      // Submitting without consent must stop before any Firebase call.
      final submit = find.byType(ElevatedButton).first;
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.textContaining('يرجى قراءة شروط الاستخدام'), findsWidgets);
      expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(
          home:
              Scaffold(body: SingleChildScrollView(child: WhyAqarSection()))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
