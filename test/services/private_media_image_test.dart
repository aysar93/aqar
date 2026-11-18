import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aqar/services/media_store.dart';
import 'package:aqar/services/media_location.dart';
import 'package:aqar/widgets/media_image.dart';

class TestUser extends Fake implements User {
  final String id;
  TestUser(this.id);
  @override
  String get uid => id;
}

class TestAuth extends Fake implements FirebaseAuth {
  User? user;
  final events = StreamController<User?>.broadcast(sync: true);
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  void change(String? uid) {
    user = uid == null ? null : TestUser(uid);
    events.add(user);
  }
}

class TestStorage extends Fake implements FirebaseStorage {}

class TestStore extends MediaStore {
  int reads = 0;
  TestStore(TestAuth auth)
      : super(storage: TestStorage(), auth: auth, bucket: 'demo-private');
  @override
  Future<Uint8List> readPrivate(String url) async {
    reads++;
    if (auth.currentUser?.uid != 'alice')
      throw StateError('Unauthorized private image');
    return base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQCu34DwADmwH/RyECiQAAAABJRU5ErkJggg==');
  }
}

void main() {
  testWidgets('private reader signs in and clears previous account image',
      (tester) async {
    final auth = TestAuth();
    final store = TestStore(auth);
    final url = MediaLocation.urlFor(
        store.bucket, 'uploads/private/license/alice/file.png');
    await tester.pumpWidget(MaterialApp(home: MediaImage(url, store: store)));
    await tester.pumpAndSettle();
    expect(store.reads, 0);
    expect(find.byType(Image), findsNothing);
    auth.change('alice');
    await tester.pumpAndSettle();
    expect(store.reads, 1);
    expect(find.byType(Image), findsOneWidget);
    auth.change(null);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    auth.change('bob');
    await tester.pumpAndSettle();
    expect(store.reads, 2);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await auth.events.close();
  });
}
