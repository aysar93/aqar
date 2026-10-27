import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'callback_gates.dart' show CallbackGate;

Future<void> main() async {
  final source = StreamController<int>(), gate = CallbackGate();
  final failure = StateError('synthetic-local-permission-error');
  var delivered = false, identicalError = false;
  final observed = Completer<void>();
  final subscription = gate.stream(source.stream).listen((_) {},
      onError: (Object error, StackTrace stack) {
    delivered = true;
    identicalError = identical(error, failure);
    observed.complete();
  });
  try {
    source.addError(failure, StackTrace.current);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (delivered) throw StateError('STREAM_ERROR_ESCAPED_GATE');
    await gate.reached.future.timeout(const Duration(seconds: 2));
    gate.release();
    await observed.future.timeout(const Duration(seconds: 2));
    if (!identicalError || gate.delivered != 1) throw StateError('ERROR_CHANGED');
    stdout.writeln(jsonEncode({'result': 'PASS_DIAGNOSTIC_STREAM_ERROR_GATE',
      'deliveredBeforeRelease': false, 'sameError': identicalError,
      'deliveredCount': gate.delivered, 'cloudCalls': 0, 'deviceActions': 0}));
  } finally {
    gate.release(); await source.close(); await subscription.cancel();
  }
}
