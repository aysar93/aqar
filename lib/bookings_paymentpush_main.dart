import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:path_provider/path_provider.dart';
import 'bookings/booking_screen.dart';
import 'bookings/booking_notification.dart';
import 'theme/app_theme.dart';
const project='aqar-paypush-uat-20261023';
final nav=GlobalKey<NavigatorState>();
final messenger=GlobalKey<ScaffoldMessengerState>();
late Map<String,dynamic> fixture;
void mark(String kind,Map<String,dynamic> values)=>print('PAYPUSH_$kind ${jsonEncode({'atUtc':DateTime.now().toUtc().toIso8601String(),'project':project,...values})}');
void open(RemoteMessage m,String source){
 final id=bookingNotificationId(m.data);
 if(id==null||id!=fixture['bookingId']){mark('REJECTED_NOTIFICATION',{'source':source});return;}
 mark('TAP',{'source':source,'bookingId':id,'notificationId':m.data['notificationId'],'messageId':m.messageId});
 nav.currentState!.push(MaterialPageRoute(builder:(_)=>BookingDetailsScreen(bookingId:id)));
}
Future<void> main()async{
 WidgetsFlutterBinding.ensureInitialized();
 if(appFlavor!='bookingsPaymentPushDiagnostic'||!const bool.fromEnvironment('PAYPUSH_DIAGNOSTIC'))throw StateError('PAYPUSH_DIAGNOSTIC_FLAVOR_REQUIRED');
 fixture=jsonDecode(await File('${(await getApplicationSupportDirectory()).path}/paypush_fixture.json').readAsString()) as Map<String,dynamic>;
 await Firebase.initializeApp();
 if(Firebase.app().options.projectId!=project||Firebase.app().options.messagingSenderId!='100428295312'||Firebase.app().options.storageBucket!='$project.firebasestorage.app')throw StateError('ISOLATED_FIREBASE_CONFIG_REQUIRED');
 final auth=FirebaseAuth.instance;
 if(auth.currentUser!=null&&auth.currentUser!.uid!=fixture['uid'])throw StateError('EXPLICIT_LOGOUT_REQUIRED_FOR_ACCOUNT_SWITCH');
 if(auth.currentUser==null)await auth.signInWithEmailAndPassword(email:fixture['email'],password:fixture['password']);
 if(auth.currentUser!.uid!=fixture['uid'])throw StateError('SYNTHETIC_ACCOUNT_MISMATCH');
 final profile=await FirebaseFirestore.instance.doc('users/${auth.currentUser!.uid}').get(const GetOptions(source:Source.server));
 if(profile.data()?['isBlocked']==true||!profile.exists)throw StateError('ACCOUNT_NOT_ACTIVE');
 FirebaseMessaging.onMessageOpenedApp.listen((m)=>open(m,'background'));
 FirebaseMessaging.onMessage.listen((m){
  final id=bookingNotificationId(m.data);if(id!=fixture['bookingId'])return;
  mark('RECEIVED',{'source':'foreground','bookingId':id,'notificationId':m.data['notificationId'],'messageId':m.messageId});
  messenger.currentState?.showMaterialBanner(MaterialBanner(content:Text(m.notification?.body??'تحديث الحجز'),actions:[TextButton(onPressed:(){messenger.currentState?.hideCurrentMaterialBanner();open(m,'foreground');},child:const Text('عرض إشعار الحجز'))]));
 });
 final permission=await FirebaseMessaging.instance.requestPermission();
 final token=await FirebaseMessaging.instance.getToken();if(token==null)throw StateError('FCM_TOKEN_NOT_AVAILABLE');
 await FirebaseFirestore.instance.doc('users/${auth.currentUser!.uid}').update({'fcmToken':token,'notificationsEnabled':true});
 FirebaseMessaging.instance.onTokenRefresh.listen((token){FirebaseFirestore.instance.doc('users/${auth.currentUser!.uid}').update({'fcmToken':token});});
 final initial=await FirebaseMessaging.instance.getInitialMessage();
 runApp(MaterialApp(navigatorKey:nav,scaffoldMessengerKey:messenger,locale:const Locale('ar'),supportedLocales:const[Locale('ar'),Locale('en')],localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:AppTheme.lightTheme,debugShowCheckedModeBanner:false,
 builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:Column(children:[const Material(color:Colors.amber,child:SafeArea(bottom:false,child:Padding(padding:EdgeInsets.all(8),child:Text('TEST / NO MONEY — مشروع مستقل')))),Expanded(child:child!)])),
 home:Scaffold(appBar:AppBar(title:Text('اختبار ${fixture['role']}')),body:Center(child:FilledButton(onPressed:()=>nav.currentState!.push(MaterialPageRoute(builder:(_)=>BookingDetailsScreen(bookingId:fixture['bookingId']))),child:const Text('فتح الحجز التجريبي'))))));
 WidgetsBinding.instance.addPostFrameCallback((_){mark('READY',{'role':fixture['role'],'uid':auth.currentUser!.uid,'permission':permission.authorizationStatus.name,'fcmTokenRegistered':true,'bookingId':fixture['bookingId']});if(initial!=null)open(initial,'cold-start');});
}
