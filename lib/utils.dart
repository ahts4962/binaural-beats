import 'dart:async';

/// A debouncer class that helps to debounce actions.
class Debouncer {
  final Duration _duration;
  void Function()? _action;
  Future<void> Function()? _asyncAction;
  Future<void> _future = Future.value();
  Timer? _timer;

  /// If any async action is running (not waiting for the debouncing timer),
  /// a [Future] that will be completed when the action completes is returned.
  /// If not, a [Future] completed with void is returned.
  Future<void> get future => _future;

  /// Creates a new debouncer with the given [milliseconds].
  Debouncer({int milliseconds = 500}) : _duration = Duration(milliseconds: milliseconds);

  /// Runs the given [action] after the debouncing timer's duration have passed.
  void run(void Function() action) {
    _timer?.cancel();
    _action = action;
    _asyncAction = null;
    _timer = Timer(_duration, () {
      _action?.call();
      _action = null;
    });
  }

  /// Runs the given [action] after the debouncing timer's duration have passed.
  ///
  /// Await [future] property to wait for the action to be completed.
  /// If the previous async action is not completed yet,
  /// [future] is completed when all actions are done.
  void runAsync(Future<void> Function() action) {
    _timer?.cancel();
    _action = null;
    _asyncAction = action;
    _timer = Timer(_duration, () {
      if (_asyncAction != null) {
        final future = _asyncAction!();
        _asyncAction = null;
        _future = _future.then((_) => future);
      }
    });
  }

  /// Immediately executes the action that is waiting for the debouncing timer if exists.
  void flush() {
    _timer?.cancel();
    _action?.call();
    _action = null;
    if (_asyncAction != null) {
      final future = _asyncAction!();
      _asyncAction = null;
      _future = _future.then((_) => future);
    }
  }
}
