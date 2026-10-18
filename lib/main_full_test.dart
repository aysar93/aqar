import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'full_test_options.dart';
import 'moderation/user_blocks.dart';
import 'main.dart' show AqarApp;
import 'providers/app_settings_provider.dart';
import 'providers/user_provider.dart';
class TestNetwork extends HttpOverrides {
 @override HttpClient createHttpClient(SecurityContext? context) {
 final c=super.createHttpClient(context);
 c.findProxy=(uri) {
 final q=fullTestOptions.projectId;
 debugPrint('MEDIA_TEST_HTTP_HOST ${uri.host}');
 final allowed=uri.scheme=='https' && (
 (uri.host=='us-central1-$q.cloudfunctions.net' && uri.path.startsWith('/mediaBrokerTest/')) ||
 (uri.host=='firebasestorage.googleapis.com' && uri.path.startsWith('/v0/b/$q-media/')) ||
 (uri.host=='res.cloudinary.com' && uri.path.startsWith('/hwxcrlcj/')) || ['identitytoolkit.googleapis.com','securetoken.googleapis.com','fonts.gstatic.com'].contains(uri.host));
 if(!allowed) throw StateError('Blocked non-test HTTP endpoint');
 return 'DIRECT';}; return c;
 }
}
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 SemanticsBinding.instance.ensureSemantics();
 HttpOverrides.global=TestNetwork();
 await Firebase.initializeApp(options:fullTestOptions);
 UserBlocks.instance.initialize();
 final prefs=await SharedPreferences.getInstance();
 await prefs.setBool('onboarding_seen',true);
 await prefs.setBool('notification_permission_postponed',true);
 runApp(MultiProvider(providers:[ChangeNotifierProvider(create:(_)=>AppSettingsProvider()..loadSettings()),ChangeNotifierProvider(create:(_)=>UserProvider())],child:const AqarApp()));
}
