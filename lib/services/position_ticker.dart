import 'dart:async';

/// Shared, lifecycle-aware playback position stream.
///
/// Replaces `AudioPlayer.createPositionStream()`, whose internal player-event
/// subscription and periodic timer keep running even after every listener has
/// cancelled. Here a single timer ticks only while the player is playing, at
/// least one widget is listening and the app is in the foreground. While the
/// app is backgrounded nothing wakes up; on return the current position is
/// emitted immediately so the UI catches up without waiting for a tick.
class PositionTicker {
  PositionTicker({
    required this._position,
    required this._isPlaying,
    required this._playerEvents,
    this.period = const Duration(milliseconds: 200),
    this._foreground = true,
  });

  final Duration Function() _position;
  final bool Function() _isPlaying;
  final Stream<Object?> _playerEvents;

  /// Interval between position updates while playing.
  final Duration period;

  final _listeners = <MultiStreamController<Duration>>{};
  StreamSubscription<Object?>? _eventSub;
  Timer? _timer;
  Duration? _lastEmitted;
  bool _foreground;
  var _disposed = false;

  /// The position stream. The same instance is returned every time, so
  /// widgets that read it inside `build` don't resubscribe on each rebuild.
  /// Each new listener receives the current position right away.
  late final stream = Stream<Duration>.multi(_onListen, isBroadcast: true);

  /// Whether the upstream player subscription is currently held.
  bool get isActive => _eventSub != null;

  /// Whether the periodic tick timer is currently running.
  bool get isTicking => _timer?.isActive ?? false;

  /// Pauses updates while the app is not visible and resumes them, emitting
  /// the current position immediately, when it comes back.
  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    _sync();
  }

  void _onListen(MultiStreamController<Duration> controller) {
    if (_disposed) {
      controller.closeSync();
      return;
    }
    _listeners.add(controller);
    controller.onCancel = () {
      _listeners.remove(controller);
      _sync();
    };
    // Asynchronous on purpose: StreamBuilder subscribes from initState, where
    // a synchronous event would trigger setState too early.
    var position = _position();
    _lastEmitted = position;
    controller.add(position);
    _sync();
  }

  void _sync() {
    var shouldRun = _foreground && _listeners.isNotEmpty;
    if (shouldRun && _eventSub == null) {
      _eventSub = _playerEvents.listen((_) => _onPlayerEvent());
      _onPlayerEvent();
    } else if (!shouldRun && _eventSub != null) {
      _eventSub?.cancel();
      _eventSub = null;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onPlayerEvent() {
    _emit();
    _timer?.cancel();
    _timer = _isPlaying() ? Timer.periodic(period, (_) => _emit()) : null;
  }

  void _emit() {
    var position = _position();
    if (position == _lastEmitted) return;
    _lastEmitted = position;
    for (var listener in List.of(_listeners)) {
      listener.add(position);
    }
  }

  void dispose() {
    _disposed = true;
    _eventSub?.cancel();
    _eventSub = null;
    _timer?.cancel();
    _timer = null;
    for (var listener in List.of(_listeners)) {
      listener.closeSync();
    }
    _listeners.clear();
  }
}
