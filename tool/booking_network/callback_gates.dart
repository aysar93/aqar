// Diagnostic adapter only, outside application. No SDK substitution or globals.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CallbackGate {
  final reached = Completer<void>();
  final _released = Completer<void>();
  int held = 0, delivered = 0;
  void release() { if (!_released.isCompleted) _released.complete(); }
  Future<T> future<T>(Future<T> original) async {
    // Only the callback is held; the original operation is not paused.
    try {
      final value = await original;
      await _hold();
      delivered++;
      return value;
    } catch (error, stack) {
      await _hold();
      delivered++;
      Error.throwWithStackTrace(error, stack);
    }
  }
  Future<void> _hold() async {
    held++;
    if (!reached.isCompleted) reached.complete();
    await _released.future;
  }
  Stream<T> stream<T>(Stream<T> original) => original
      .transform(StreamTransformer<T, _CallbackEvent<T>>.fromHandlers(
        handleData: (value, sink) => sink.add(_CallbackEvent<T>(value: value)),
        handleError: (Object error, StackTrace stack, sink) =>
            sink.add(_CallbackEvent<T>(error: error, stack: stack)),
      ))
      .asyncMap((event) async {
        await _hold();
        delivered++;
        if (event.error != null) {
          Error.throwWithStackTrace(event.error!, event.stack!);
        }
        return event.value as T;
      });
}

class _CallbackEvent<T> {
  final T? value;
  final Object? error;
  final StackTrace? stack;
  _CallbackEvent({this.value, this.error, this.stack});
}

Future<void> main() async {
  final callable = CallbackGate(), query = CallbackGate(), document = CallbackGate();
  final q = StreamController<int>(), d = StreamController<int>();
  final events = <String>[];
  final subscriptions = [
    query.stream(q.stream).listen((_) => events.add('query')),
    document.stream(d.stream).listen((_) => events.add('document')),
  ];
  final completion = callable.future(Future.value(1)).then((_) => events.add('callable'));
  q.add(1); d.add(1);
  await Future.wait([callable.reached.future, query.reached.future, document.reached.future])
      .timeout(const Duration(seconds: 3));
  if (events.isNotEmpty) throw StateError('EARLY_DELIVERY');
  callable.release(); await completion;
  if (events.join(',') != 'callable' || query.delivered != 0 || document.delivered != 0) {
    throw StateError('GATE_COUPLING');
  }
  final qDelivered = Completer<void>();
  // Let the event loop progress; do not pause the isolate.
  query.release();
  Timer.run(() => qDelivered.complete()); await qDelivered.future;
  if (!events.contains('query') || document.delivered != 0) throw StateError('QUERY_NOT_INDEPENDENT');
  document.release();
  await Future<void>.delayed(Duration.zero);
  if (!events.contains('document')) throw StateError('DOCUMENT_NOT_RELEASED');
  await q.close(); await d.close();
  for (final s in subscriptions) { await s.cancel(); }
  stdout.writeln(jsonEncode({
    'result':'PASS_LOCAL_DART_CALLBACK_ADAPTER_ONLY',
    'beforeReleaseDelivered':0, 'releaseOrder':events,
    'channels':['callable','query','document'], 'cloudCalls':0, 'deviceActions':0,
    'limits':['NOT SDK invocation', 'NOT UI integration', 'NOT S3/V5 UAT'],
  }));
}
