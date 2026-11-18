import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/screens/onboarding/splash_screen.dart';
import 'package:aqar/screens/onboarding/premium_splash.dart';
class HangingAudio extends Fake implements AudioPlayer {
 @override Future<void> setAudioContext(AudioContext context)=>Completer<void>().future;
 @override Future<void> pause() async {}
 @override Future<void> resume() async {}
 @override Future<void> seek(Duration position) async {}
 @override Future<void> dispose() async {}
}
void main() {
 testWidgets('splash animation advances even if optional audio never initializes',(tester) async {
  await tester.pumpWidget(MaterialApp(home:SplashScreen(audioPlayer:HangingAudio())));
  await tester.pump(const Duration(seconds:3));
  await tester.pump(const Duration(milliseconds:500));
  await tester.pump(const Duration(milliseconds:500));
  expect(tester.widget<PremiumSplash>(find.byType(PremiumSplash)).animation.value,greaterThan(0));
  await tester.pumpWidget(const SizedBox());await tester.pump(const Duration(seconds:4));
  expect(tester.takeException(),isNull);
 });
 testWidgets('resume restarts a splash interrupted at the zero animation frame',(tester) async {
  await tester.pumpWidget(MaterialApp(home:SplashScreen(audioPlayer:HangingAudio())));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump(const Duration(milliseconds:100));
  await tester.pump(const Duration(milliseconds:400));
  expect(tester.widget<PremiumSplash>(find.byType(PremiumSplash)).animation.value,greaterThan(0));
  await tester.pumpWidget(const SizedBox());await tester.pump(const Duration(seconds:4));
  expect(tester.takeException(),isNull);
 });
}
