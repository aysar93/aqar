import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file/local.dart';
import 'package:aqar/widgets/media_image.dart';

class DiskFixtureCache extends Fake implements BaseCacheManager {
  final File file;
  bool online = false;
  int reads = 0;
  DiskFixtureCache(this.file);
  @override
  Stream<FileResponse> getFileStream(String url,
      {String? key,
      Map<String, String>? headers,
      bool withProgress = false}) async* {
    reads++;
    if (!online) throw const SocketException('synthetic offline');
    yield FileInfo(const LocalFileSystem().file(file.path), FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)), url);
  }
}

void main() {
  testWidgets(
      'public image retries after a failed request without a metadata event',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('aqar-media-widget-');
    final file = File('${dir.path}/synthetic.png')
      ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQCu34DwADmwH/RyECiQAAAABJRU5ErkJggg=='));
    final cache = DiskFixtureCache(file);
    await tester.pumpWidget(MaterialApp(
        home: MediaImage('https://synthetic.invalid/public.png',
            publicCacheManager: cache,
            errorBuilder: (_, __, ___) => const Text('offline'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(cache.reads, 1);
    cache.online = true;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 100));
    expect(cache.reads, greaterThan(1));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
      final images = tester.widgetList<RawImage>(find.byType(RawImage));
      if (images.any((x) => x.image != null)) break;
    }
    expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((x) => x.image != null),
        isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // Windows native image buffers may mmap this file until process exit.
    // The parent test runner removes this exact synthetic path after exit.
    // ignore: avoid_print
    print('SYNTHETIC_TEMP_DIR=${dir.path}');
  });
}
