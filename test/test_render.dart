import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test render', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Container(
          width: 360,
          height: 640,
          color: Colors.red,
        ),
      ),
    );

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    print(
        'Rendered bytes: ${bytes.length}, image: ${image.width}x${image.height}');
    File('test_smoke.png').writeAsBytesSync(bytes);
  });
}
