import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/media_store.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'synthetic-owner';
  @override
  bool get isAnonymous => false;
}

class TestAuth extends Fake implements FirebaseAuth {
  final User? user;
  TestAuth(this.user);
  @override
  User? get currentUser => user;
}

class NoClientDeletion extends Fake implements FirebaseStorage {
  @override
  Reference ref([String? path]) =>
      throw StateError('A client must never issue physical deletion');
}

void main() {
  test('UI cleanup retains shared public and private bytes without Storage IO',
      () async {
    final store = MediaStore(
        storage: NoClientDeletion(),
        auth: TestAuth(TestUser()),
        bucket: 'demo-media');
    for (final path in [
      'uploads/public/banner/synthetic-owner/image.png',
      'uploads/private/license/synthetic-owner/image.png',
      'uploads/private/chat_audio/chat/synthetic-owner/audio.m4a'
    ]) {
      await store.deletePath(path);
    }
  });
  test('UI cleanup cannot target archives, URLs or anonymous sessions',
      () async {
    final store = MediaStore(
        storage: NoClientDeletion(),
        auth: TestAuth(TestUser()),
        bucket: 'demo-media');
    for (final path in [
      'staging/private/archive.jpg',
      'https://example.test/a'
    ]) {
      await expectLater(store.deletePath(path), throwsStateError);
    }
    final signedOut = MediaStore(
        storage: NoClientDeletion(),
        auth: TestAuth(null),
        bucket: 'demo-media');
    await expectLater(signedOut.deletePath('uploads/public/avatar/u/a.png'),
        throwsStateError);
  });
}
