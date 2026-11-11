import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_reels_screen.dart';

class MockSnapshotMeta extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}

class MockCommentDoc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  MockCommentDoc(this._id, this._data, this._ref);
  final String _id;
  final Map<String, dynamic> _data;
  final DocumentReference<Map<String, dynamic>> _ref;

  @override
  String get id => _id;
  @override
  Map<String, dynamic> data() => _data;
  @override
  DocumentReference<Map<String, dynamic>> get reference => _ref;
}

class MockCommentRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  MockCommentRef(this.id, this._store);
  @override
  final String id;
  final List<Map<String, dynamic>> _store;

  @override
  Future<void> delete() async {
    _store.removeWhere((item) => item['id'] == id);
  }
}

class MockCommentsSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  MockCommentsSnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  SnapshotMetadata get metadata => MockSnapshotMeta();
}

Widget testApp(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void main() {
  group('Reels Comments & Nested Replies Lifecycle and Permissions Test', () {
    testWidgets('Complete lifecycle: add comment, reply, close/reopen, verify persistence, author & admin permissions',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Simulating database collection for comments
      final dbComments = <Map<String, dynamic>>[
        {
          'id': 'comment-root-1',
          'userId': 'user-ahmed',
          'userName': 'أحمد العاني',
          'text': 'ما هي أوقات الدخول والخروج للشاليه؟',
          'createdAt': Timestamp.now(),
        },
      ];

      final streamController = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      addTearDown(streamController.close);

      void emitSnapshot() {
        final docs = dbComments.map((data) {
          final id = data['id'] as String;
          return MockCommentDoc(id, data, MockCommentRef(id, dbComments));
        }).toList();
        streamController.add(MockCommentsSnapshot(docs));
      }

      // Step 1: Open Comments Sheet as a normal user "user-saad"
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BookingReelCommentsSheet(
              reelId: 'reel-test-101',
              admin: false,
              currentUserId: () => 'user-saad',
              commentsStream: streamController.stream,
            ),
          ),
        ),
      );

      emitSnapshot();
      await tester.pumpAndSettle();

      // Verify root comment is present
      expect(find.text('أحمد العاني'), findsOneWidget);
      expect(find.text('ما هي أوقات الدخول والخروج للشاليه؟'), findsOneWidget);

      // Verify normal user "user-saad" CANNOT delete "user-ahmed"'s comment
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Step 2: Tap "رد" on Ahmed's comment
      await tester.tap(find.text('رد'));
      await tester.pumpAndSettle();

      // Verify active reply banner appears with target author
      expect(find.text('الرد على أحمد العاني'), findsOneWidget);
      expect(find.text('اكتب ردك على أحمد العاني...'), findsOneWidget);

      // Step 3: Simulate adding the reply into the database
      final replyDoc = {
        'id': 'reply-1',
        'userId': 'user-saad',
        'userName': 'سعد الراوي',
        'text': 'الدخول الساعة 2 ظهراً والخروج 11 صباحاً.',
        'parentId': 'comment-root-1',
        'replyToAuthor': 'أحمد العاني',
        'createdAt': Timestamp.now(),
      };
      dbComments.add(replyDoc);
      emitSnapshot();
      await tester.pumpAndSettle();

      // Verify reply rendered under parent comment with badge
      expect(find.text('سعد الراوي'), findsOneWidget);
      expect(find.text('رد على @أحمد العاني'), findsOneWidget);
      expect(find.text('الدخول الساعة 2 ظهراً والخروج 11 صباحاً.'), findsOneWidget);

      // User "user-saad" is author of reply-1, so delete icon appears ONLY for reply-1 (1 widget)
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Step 4: Close sheet and reopen (simulate unmount and mount)
      await tester.pumpWidget(testApp(const Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();
      expect(find.text('أحمد العاني'), findsNothing);

      // Reopen sheet as Admin
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BookingReelCommentsSheet(
              reelId: 'reel-test-101',
              admin: true,
              currentUserId: () => 'admin-user',
              commentsStream: streamController.stream,
            ),
          ),
        ),
      );
      emitSnapshot();
      await tester.pumpAndSettle();

      // Verify both parent and reply persisted from dbComments
      expect(find.text('أحمد العاني'), findsOneWidget);
      expect(find.text('سعد الراوي'), findsOneWidget);
      expect(find.text('رد على @أحمد العاني'), findsOneWidget);

      // Admin has delete permissions on ALL comments (2 delete buttons)
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

      // Step 5: Admin deletes the reply
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.last);
      emitSnapshot();
      await tester.pumpAndSettle();

      // Verify reply was deleted from db and UI
      expect(dbComments.any((c) => c['id'] == 'reply-1'), isFalse);
      expect(find.text('الدخول الساعة 2 ظهراً والخروج 11 صباحاً.'), findsNothing);
      expect(find.text('أحمد العاني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

