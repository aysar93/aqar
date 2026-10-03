import 'dart:async';

/// Route-owned replay of one upstream subscription. The last consumer cancels
/// the upstream and clears its cached value, including account-specific data.
class SharedStream<T> {
  SharedStream(this.source);
  final Stream<T> source;
  final Set<MultiStreamController<T>> _listeners = {};
  StreamSubscription<T>? _subscription;
  T? _last;
  bool _hasLast = false;
  int _generation = 0;
  late final Stream<T> stream = Stream<T>.multi((controller) {
    _listeners.add(controller);
    if (_hasLast) controller.add(_last as T);
    if (_subscription == null) {
      final generation = ++_generation;
      _subscription = source.listen((value) {
        if (generation != _generation) return;
        _last = value;
        _hasLast = true;
        for (final listener in _listeners.toList()) {
          listener.add(value);
        }
      }, onError: (Object error, StackTrace stack) {
        for (final listener in _listeners.toList()) {
          listener.addError(error, stack);
        }
      }, onDone: () {
        for (final listener in _listeners.toList()) {
          listener.close();
        }
      });
    }
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty) {
        _generation++;
        _subscription?.cancel();
        _subscription = null;
        _last = null;
        _hasLast = false;
      }
    };
  });
}
