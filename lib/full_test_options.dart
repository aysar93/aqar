import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
const androidOptions = FirebaseOptions(apiKey: const String.fromEnvironment('MEDIA_TEST_FIREBASE_API_KEY', defaultValue: 'media-test-build-only-no-auth'),appId:"1:935194200707:android:662a3c4dec8fd93edce9b6",messagingSenderId:"935194200707",projectId:"aqar-media-test-20261018",storageBucket:"aqar-media-test-20261018-media");
const iosOptions = FirebaseOptions(apiKey: const String.fromEnvironment('MEDIA_TEST_FIREBASE_API_KEY', defaultValue: 'media-test-build-only-no-auth'),appId:"1:935194200707:ios:e229b58c4135c5f3dce9b6",messagingSenderId:"935194200707",projectId:"aqar-media-test-20261018",storageBucket:"aqar-media-test-20261018-media",iosBundleId:"local.aqar.fullMediaTest");
FirebaseOptions get fullTestOptions => Platform.isIOS ? iosOptions : androidOptions;
