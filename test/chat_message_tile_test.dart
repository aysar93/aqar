import 'package:aqar/chat/widgets/chat_message_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget frame(Widget child) => MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), surface: Color(0xFF1E293B)),
      fontFamily: 'SplashTajawal',
    ),
    home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Padding(padding: const EdgeInsets.all(16), child: child))));

void main() {
  setUpAll(() async {
    final font = FontLoader('SplashTajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('Tap and long press expose message actions', (tester) async {
    var actions = 0;
    await tester.pumpWidget(frame(ChatMessageTile(
        data: const {'type': 'text', 'message': 'رسالة رسمية'},
        isMe: true,
        onActions: () => actions++)));
    await tester.tap(find.text('رسالة رسمية'));
    expect(actions, 1);
    await tester.longPress(find.text('رسالة رسمية'));
    expect(actions, 2);
  });
  testWidgets('Deletion replaces both content and quoted reply',
      (tester) async {
    await tester.pumpWidget(frame(ChatMessageTile(
        data: const {'type': 'text', 'message': 'رد', 'replyToId': 'original'},
        isMe: true,
        reply: const {'deletedAt': 'now', 'message': 'محتوى قديم'},
        onActions: () {})));
    expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);
    expect(find.text('محتوى قديم'), findsNothing);
    await tester.pumpWidget(frame(ChatMessageTile(data: const {
      'deletedAt': 'now',
      'type': 'image',
      'imageUrl': 'https://example.com/private.png',
      'message': 'محتوى قديم'
    }, isMe: false, onActions: () {})));
    expect(find.byType(Image), findsNothing);
    expect(find.text('محتوى قديم'), findsNothing);
  });
  testWidgets('Formal message layout fits narrow phones with long Arabic text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final timestamp = Timestamp.fromDate(DateTime(2026, 10, 2, 15, 30));
    await tester.pumpWidget(frame(RepaintBoundary(
        key: const Key('preview'),
        child: ColoredBox(
            color: const Color(0xFF0F172A),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('عقارات الأنبار',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold))),
                  ChatMessageTile(data: {
                    'type': 'text',
                    'message':
                        'أهلاً بك، كيف يمكننا مساعدتك في العثور على العقار المناسب؟',
                    'createdAt': timestamp
                  }, isMe: false, onActions: () {}),
                  ChatMessageTile(
                      data: {
                        'type': 'text',
                        'message':
                            'أبحث عن منزل للبيع في الرمادي، هل يتوفر عقار يناسب ميزانيتي؟',
                        'createdAt': timestamp,
                        'status': 'read',
                        'replyToId': 'first'
                      },
                      isMe: true,
                      reply: const {'message': 'كيف يمكننا مساعدتك؟'},
                      onActions: () {}),
                  ChatMessageTile(data: {
                    'type': 'property',
                    'createdAt': timestamp,
                    'status': 'read',
                    'property': {
                      'id': 'demo',
                      'title': 'منزل للبيع في الرمادي',
                      'price': 150000000,
                      'location': 'الرمادي — حي التأميم',
                      'adType': 'بيع',
                      'number': 124,
                      'imageUrl': ''
                    }
                  }, isMe: true, onActions: () {}),
                  ChatMessageTile(
                      data: {'deletedAt': 'now', 'createdAt': timestamp},
                      isMe: false,
                      onActions: () {}),
                ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const Key('preview')),
        matchesGoldenFile('goldens/chat_formal.png'));
  });
}
