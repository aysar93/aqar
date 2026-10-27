// Local preparation only. Same package:http + IOClient as the video path.
// No Firebase/auth/device calls. Never install a global override or trust bypass.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class BodyGateClient extends http.BaseClient {
  final http.Client inner;
  final int offset;
  final Completer<void> prefixQueued = Completer<void>();
  final Completer<void> release = Completer<void>();
  BodyGateClient(this.inner, this.offset);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host != '127.0.0.1' || request.url.scheme != 'http') {
      throw StateError('LOCAL_ONLY');
    }
    // Do not capture headers, URLs, tokens or body contents in evidence.
    final stream = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = request.contentLength
      ..followRedirects = false;
    final result = inner.send(stream);
    unawaited(() async {
      var count = 0;
      try {
        await for (final bytes in request.finalize()) {
          var start = 0;
          if (count < offset && count + bytes.length >= offset) {
            final length = offset - count;
            stream.sink.add(bytes.sublist(0, length));
            count += length;
            start = length;
            prefixQueued.complete();
            await release.future;
          }
          if (start < bytes.length) {
            stream.sink.add(bytes.sublist(start));
            count += bytes.length - start;
          }
        }
        await stream.sink.close();
      } catch (_) {
        // No sensitive exception strings.
      }
    }());
    return result;
  }
  @override
  void close() => inner.close();
}

Future<void> main() async {
  const total = 4 * 1024 * 1024, cut = total ~/ 2;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final observed = Completer<void>(), aborted = Completer<void>();
  var received = 0, complete = false, commits = 0, failed = false;
  server.listen((request) async {
    try {
      await for (final bytes in request) {
        received += bytes.length;
        if (received == cut && !observed.isCompleted) observed.complete();
        if (received > cut) throw StateError('OVERSHOOT');
      }
      complete = true;
      if (received == total) commits++;
      request.response.statusCode = 200;
      await request.response.close();
    } catch (_) {
      if (!aborted.isCompleted) aborted.complete();
    }
  });
  final gate = BodyGateClient(IOClient(), cut);
  final uri = Uri.parse('http://127.0.0.1:${server.port}/synthetic-chunk');
  // Same http.post(...body: bytes.sublist(offset,end)) call form as app source.
  // This does not invoke BookingMediaService, Auth, or the Functions SDK.
  final bytes = Uint8List(total);
  final result = http.runWithClient(() async {
    try {
      await http.post(uri,
          headers: {'Content-Type': 'application/octet-stream'},
          body: bytes.sublist(0, total));
    } catch (_) { failed = true; }
  }, () => gate);
  try {
    await gate.prefixQueued.future.timeout(const Duration(seconds: 8));
    await observed.future.timeout(const Duration(seconds: 8));
    final observedBeforeCut = received;
    final cutAt = DateTime.now().toUtc().toIso8601String();
    gate.close();
    await aborted.future.timeout(const Duration(seconds: 8));
    await result.timeout(const Duration(seconds: 8));
    if (observedBeforeCut != cut || received != cut || complete || commits != 0 || !failed) {
      throw StateError('CONTROL_NOT_PROVEN');
    }
    stdout.writeln(jsonEncode({
      'result': 'PASS_LOCAL_DART_HTTP_CONTROL_ONLY',
      'transport': 'package:http 1.6.0 / IOClient / real loopback TCP',
      'totalBytes': total, 'serverObservedBeforeClose': observedBeforeCut,
      'serverObservedFinal': received, 'serverBodyComplete': complete,
      'syntheticModelCommits': commits, 'clientFailed': failed, 'cutAtUtc': cutAt,
      'cloudCalls': 0, 'deviceActions': 0,
      'limits': ['NOT BookingMediaService invocation', 'NOT Firebase SDK',
        'NOT physical radio cut', 'NOT Staging UAT',
        'Local HTTP fixture only; production TLS untouched'],
    }));
  } finally {
    gate.close();
    if (!gate.release.isCompleted) gate.release.completeError(StateError('STOPPED'));
    await server.close(force: true);
  }
}
