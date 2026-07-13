part of 'navigation_controller.dart';

class _LifecycleTransitionQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> add(Future<void> Function() transition) {
    final queued = _tail.then(
      (_) => transition(),
      onError: (_) => transition(),
    );
    _tail = queued.then<void>((_) {}, onError: (_) {});
    return queued;
  }
}
