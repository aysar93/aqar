import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/features/property_card/property_card_data.dart';
import 'package:aqar/features/property_card/property_card_social_service.dart';

Future<ui.Image> _decodeFile(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Renders the card widget off-screen and captures a PNG at pixelRatio 3.0.
/// Returns 1080×1920 PNG bytes.
Future<({Uint8List bytes, int width, int height})> _captureCard(
    WidgetTester tester, PropertyCardData data) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: key,
          child: PropertyCardSocialService.buildWidget(data),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;

  // Wrap GPU async ops in runAsync so they don't block the fake async zone.
  late Uint8List pngBytes;
  late int imgWidth;
  late int imgHeight;

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    pngBytes = byteData!.buffer.asUint8List();
    imgWidth = image.width;
    imgHeight = image.height;
  });

  return (bytes: pngBytes, width: imgWidth, height: imgHeight);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Villa card renders at 1080x1920', (tester) async {
    ui.Image? logoImg;
    ui.Image? houseImg;

    await tester.runAsync(() async {
      final cairoFile = File('test_cairo.ttf');
      if (cairoFile.existsSync()) {
        final fontBytes = await cairoFile.readAsBytes();
        final fontLoader = FontLoader('Cairo');
        fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await fontLoader.load();
        print('Cairo font loaded.');
      }
      if (File('assets/images/logo.png').existsSync()) {
        logoImg = await _decodeFile('assets/images/logo.png');
        print('Logo loaded: ${logoImg!.width}x${logoImg!.height}');
      }
      if (File('assets/images/defaults/house.png').existsSync()) {
        houseImg = await _decodeFile('assets/images/defaults/house.png');
        print('House image loaded: ${houseImg!.width}x${houseImg!.height}');
      }
    });

    PropertyCardSocialService.testLogoImage = logoImg;
    PropertyCardSocialService.testHeroImage = houseImg;
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final villaData = PropertyCardData(
      id: 'villa-test-123',
      number: 67,
      title: 'فيلا سكنية فاخرة بتشطيب سوبر ديلوكس',
      imageUrl: 'assets/images/defaults/house.png',
      images: ['assets/images/defaults/house.png'],
      propertyType: 'فيلا',
      adType: 'بيع',
      price: 285000000,
      negotiable: true,
      location: 'الرمادي - حي النور',
      city: 'الرمادي',
      areaName: 'حي النور',
      landmark: 'قرب جامع الدولة الكبير',
      rooms: 5,
      bathrooms: 4,
      livingRooms: 2,
      parking: 2,
      area: 350,
      frontage: 15,
      depth: 23,
      floors: 2,
      buildYear: 2023,
      documentType: 'طابو ملك صرف',
      furnitureStatus: 'نصف مفروش',
      availabilityStatus: 'available',
      features: ['مسبح', 'حديقة', 'كراج سيارات', 'كاميرات مراقبة'],
      description: 'فيلا سكنية بتصميم هندسي راقي وتشطيبات مستوردة.',
      contactName: 'مكتب الرافدين للعقارات',
      contactPhone: '0780 123 4567',
      contactWhatsapp: '0780 123 4567',
      isOffice: true,
      isVerified: true,
      isFeatured: true,
      cardDate: DateTime.now(),
    );

    final result = await _captureCard(tester, villaData);
    expect(result.width, 1080);
    expect(result.height, 1920);
    File('test_villa_output.png').writeAsBytesSync(result.bytes);
    print('Villa: ${result.width}x${result.height} (${result.bytes.length} bytes) ✅');

    PropertyCardSocialService.testLogoImage = null;
    PropertyCardSocialService.testHeroImage = null;
  });

  testWidgets('Land card renders at 1080x1920', (tester) async {
    ui.Image? logoImg;
    ui.Image? landImg;

    await tester.runAsync(() async {
      if (File('assets/images/logo.png').existsSync()) {
        logoImg = await _decodeFile('assets/images/logo.png');
        print('Logo loaded: ${logoImg!.width}x${logoImg!.height}');
      }
      if (File('assets/images/defaults/land.png').existsSync()) {
        landImg = await _decodeFile('assets/images/defaults/land.png');
        print('Land image loaded: ${landImg!.width}x${landImg!.height}');
      }
    });

    PropertyCardSocialService.testLogoImage = logoImg;
    PropertyCardSocialService.testHeroImage = landImg;
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final landData = PropertyCardData(
      id: 'land-test-456',
      number: 89,
      title: 'قطعة أرض سكنية زاوية بموقع استثماري',
      imageUrl: 'assets/images/defaults/land.png',
      images: ['assets/images/defaults/land.png'],
      propertyType: 'أرض',
      adType: 'بيع',
      price: 120000000,
      negotiable: false,
      location: 'الرمادي - حي 7 نيسان',
      city: 'الرمادي',
      areaName: 'حي 7 نيسان',
      landmark: 'شارع 30 الرئيسي',
      rooms: 0,
      bathrooms: 0,
      livingRooms: 0,
      parking: 0,
      area: 600,
      frontage: 20,
      depth: 30,
      buildYear: 0,
      documentType: 'طابو ملك صرف',
      furnitureStatus: '',
      availabilityStatus: 'available',
      features: ['على شارعين', 'ركن', 'كاملة الخدمات'],
      description: 'أرض سكنية زاوية واجهة 20 متر، جاهزة للبناء.',
      contactName: 'عقارات الانبار',
      contactPhone: '0781 999 8877',
      contactWhatsapp: '0781 999 8877',
      isOffice: true,
      isVerified: true,
      isFeatured: false,
      cardDate: DateTime.now(),
    );

    final result = await _captureCard(tester, landData);
    expect(result.width, 1080);
    expect(result.height, 1920);
    File('test_land_output.png').writeAsBytesSync(result.bytes);
    print('Land: ${result.width}x${result.height} (${result.bytes.length} bytes) ✅');

    PropertyCardSocialService.testLogoImage = null;
    PropertyCardSocialService.testHeroImage = null;
  });
}
