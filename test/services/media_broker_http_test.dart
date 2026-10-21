import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aqar/services/media_store.dart';
import 'package:aqar/services/media_location.dart';

class DemoApp extends Fake implements FirebaseApp {
  @override
  FirebaseOptions get options => const FirebaseOptions(
      apiKey: 'demo',
      appId: 'demo',
      messagingSenderId: '123',
      projectId: 'demo-media-http');
}

class DemoUser extends Fake implements User {
  final String id;
  DemoUser(this.id);
  @override
  String get uid => id;
  @override
  bool get isAnonymous => false;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'demo-only-local-token';
}

class DemoAuth extends Fake implements FirebaseAuth {
  User user = DemoUser('alice');
  @override
  User? get currentUser => user;
  @override
  FirebaseApp get app => DemoApp();
}

class NoStorageSDK extends Fake implements FirebaseStorage {}

void main() {
  test(
      'real loopback HTTP retries, operation isolation and authenticated private reads',
      () async {
    const bucket = 'demo-media-http';
    final auth = DemoAuth();
    final store =
        MediaStore(storage: NoStorageSDK(), auth: auth, bucket: bucket);
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]);
    final operations = <String>[];
    var transient = true;
    var changeAccount = false;
    var stallBody = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 9396);
    server.listen((request) async {
      expect(request.headers.value('Authorization'),
          'Bearer demo-only-local-token');
      if (request.uri.path == '/uploadMedia') {
        final body = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        operations.add(body['uploadId'] as String);
        expect(base64Decode(body['content'] as String), orderedEquals(bytes));
        if (transient) {
          transient = false;
          request.response.statusCode = 503;
          await request.response.close();
          return;
        }
        final private = body['purpose'] == 'license';
        final path =
            'uploads/${private ? 'private' : 'public'}/${body['purpose']}/alice/${body['uploadId']}.png';
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(
            {'path': path, 'url': MediaLocation.urlFor(bucket, path)}));
      } else {
        expect(request.uri.path, '/readPrivateMedia');
        request.response.headers.contentType = ContentType('image', 'png');
        if (stallBody && request.method == 'GET') {
          request.response.add(bytes.sublist(0, 1));
          await request.response.flush();
          return;
        }
        if (changeAccount) auth.user = DemoUser('bob');
        if (request.method != 'HEAD') request.response.add(bytes);
      }
      await request.response.close();
    });
    final folder = await Directory.systemTemp.createTemp('media-http-test-');
    final file = File('${folder.path}/fixture.png');
    await file.writeAsBytes(bytes);
    try {
      final public =
          await store.uploadImage(file, purpose: MediaPurpose.property);
      expect(operations.length, 2);
      expect(operations[0], operations[1]);
      expect(public['path'], startsWith('uploads/public/property/alice/'));
      final private =
          await store.uploadImage(file, purpose: MediaPurpose.license);
      expect(operations[2], isNot(operations[0]));
      expect(await store.readPrivate(private['url']!), orderedEquals(bytes));
      expect(await store.privateContentType(private['url']!), 'image/png');
      final bounded = MediaStore(
          storage: NoStorageSDK(),
          auth: auth,
          bucket: bucket,
          responseTimeout: const Duration(milliseconds: 100));
      stallBody = true;
      await expectLater(bounded.readPrivate(private['url']!),
          throwsA(isA<TimeoutException>()));
      stallBody = false;
      expect(await store.readPrivate(private['url']!), orderedEquals(bytes));
      changeAccount = true;
      await expectLater(store.readPrivate(private['url']!), throwsStateError);
    } finally {
      await server.close(force: true);
      await file.delete();
      await folder.delete();
    }
  });
}
