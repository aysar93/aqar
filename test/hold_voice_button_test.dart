import 'dart:async';
import 'dart:io';
import 'package:aqar/chat/widgets/hold_voice_button.dart';
import 'package:aqar/chat/widgets/voice_recorder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Platform fakes exercise permission and pointer-release races without a microphone.
// ignore: depend_on_referenced_packages
import 'package:record_platform_interface/record_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class RecorderFake extends RecordPlatform {
  int starts = 0, stops = 0;
  String? path;
  Completer<bool>? permission;
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      permission == null ? true : await permission!.future;
  @override
  Future<void> start(String recorderId, RecordConfig config,
      {required String path}) async {
    starts++;
    this.path = path;
  }

  @override
  Future<String?> stop(String recorderId) async {
    stops++;
    return path;
  }

  @override
  Future<void> cancel(String recorderId) async {}
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PathsFake extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecorderFake recorder;
  setUp(() {
    recorder = RecorderFake();
    RecordPlatform.instance = recorder;
    PathProviderPlatform.instance = PathsFake();
  });
  Widget frame(Future<void> Function(VoiceRecording) onComplete) => MaterialApp(
      home: Scaffold(
          body: HoldVoiceButton(
              enabled: true,
              maxSeconds: 120,
              onComplete: onComplete,
              onError: (message) => fail(message))));
  testWidgets('long hold sends once on release without opening preview',
      (tester) async {
    final sent = <VoiceRecording>[];
    await tester.pumpWidget(frame((value) async => sent.add(value)));
    await tester.pump();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(HoldVoiceButton)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(recorder.starts, 1);
    expect(sent, isEmpty);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(sent, hasLength(1));
    expect(sent.single.seconds, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'release during permission request never leaves recording running',
      (tester) async {
    recorder.permission = Completer<bool>();
    var sent = 0;
    await tester.pumpWidget(frame((_) async => sent++));
    await tester.pump();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(HoldVoiceButton)));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    recorder.permission!.complete(true);
    await tester.pumpAndSettle();
    expect(recorder.starts, 0);
    expect(sent, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
