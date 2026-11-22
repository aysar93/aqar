import 'dart:async';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/banners/banner_service.dart';
import 'package:aqar/screens/admin/add_banner_screen.dart';
import 'package:aqar/screens/admin/banner_management_screen.dart';
import 'package:aqar/widgets/banner_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'existing admin entry points default to home; booking editors keep scope',
      () {
    expect(const BannerManagementScreen().placement, BannerPlacement.home);
    expect(const AddBannerScreen().placement, BannerPlacement.home);
    expect(
        const BannerManagementScreen(placement: BannerPlacement.bookings)
            .placement,
        BannerPlacement.bookings);
    expect(const AddBannerScreen(placement: BannerPlacement.bookings).placement,
        BannerPlacement.bookings);
    expect(BannerService.collectionName(BannerPlacement.home), 'banners');
    expect(BannerService.collectionName(BannerPlacement.bookings),
        'booking_banners');
  });
  testWidgets('empty and failed booking banners leave places usable',
      (tester) async {
    final stream = StreamController<List<BannerModel>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      BannerSlider(stream: stream.stream),
      const Text('Places')
    ]))));
    stream.add([]);
    await tester.pump();
    expect(find.text('Places'), findsOneWidget);
    stream.addError(StateError('unavailable'));
    await tester.pump();
    expect(find.text('Places'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
