import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/position_ticker.dart';

void main() {
  group('PositionTicker', () {
    late StreamController<Object?> events;
    late Duration position;
    late bool playing;
    late PositionTicker ticker;

    void setUpTicker(FakeAsync async) {
      events = StreamController<Object?>.broadcast();
      position = Duration.zero;
      playing = true;
      ticker = PositionTicker(
        position: () => position,
        isPlaying: () => playing,
        playerEvents: events.stream,
      );
      // Simulated playback: the position advances with fake time.
      Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (playing) position += const Duration(milliseconds: 100);
      });
    }

    test('drops a small backward correction at song start', () {
      fakeAsync((async) {
        setUpTicker(async);
        var values = <Duration>[];
        var sub = ticker.stream.listen(values.add);
        async.elapse(const Duration(seconds: 1));
        var shown = values.last;

        // The player corrects its extrapolated position back by ~0.3s.
        position = shown - const Duration(milliseconds: 300);
        events.add(null);
        async.flushMicrotasks();
        expect(values.last, shown);

        // Once real playback passes the shown position, updates resume.
        async.elapse(const Duration(seconds: 1));
        expect(values.last, greaterThan(shown));
        for (var i = 1; i < values.length; i++) {
          expect(values[i], greaterThanOrEqualTo(values[i - 1]));
        }
        sub.cancel();
        ticker.dispose();
      });
    });

    test('a seek or track change may still move the position back', () {
      fakeAsync((async) {
        var discontinuities = StreamController<Object?>.broadcast();
        events = StreamController<Object?>.broadcast();
        position = const Duration(seconds: 5);
        playing = false;
        ticker = PositionTicker(
          position: () => position,
          isPlaying: () => playing,
          playerEvents: events.stream,
          discontinuities: discontinuities.stream,
        );
        var values = <Duration>[];
        var sub = ticker.stream.listen(values.add);
        async.flushMicrotasks();

        // Small seek back: the player event is held, the discontinuity wins.
        position = const Duration(seconds: 4, milliseconds: 500);
        events.add(null);
        discontinuities.add(null);
        async.flushMicrotasks();
        expect(values.last, const Duration(seconds: 4, milliseconds: 500));

        // A large jump back (new track) passes even without a discontinuity.
        position = Duration.zero;
        events.add(null);
        async.flushMicrotasks();
        expect(values.last, Duration.zero);

        sub.cancel();
        ticker.dispose();
      });
    });

    test('returns the same stream instance on every access', () {
      fakeAsync((async) {
        setUpTicker(async);
        expect(identical(ticker.stream, ticker.stream), isTrue);
        ticker.dispose();
      });
    });

    test('emits the current position to each new listener', () {
      fakeAsync((async) {
        setUpTicker(async);
        position = const Duration(seconds: 42);
        var first = <Duration>[];
        var second = <Duration>[];
        var sub1 = ticker.stream.listen(first.add);
        async.flushMicrotasks();
        var sub2 = ticker.stream.listen(second.add);
        async.flushMicrotasks();
        expect(first.first, const Duration(seconds: 42));
        expect(second.first, const Duration(seconds: 42));
        sub1.cancel();
        sub2.cancel();
        ticker.dispose();
      });
    });

    test('ticks while playing and stops when the last listener leaves', () {
      fakeAsync((async) {
        setUpTicker(async);
        var values = <Duration>[];
        var sub = ticker.stream.listen(values.add);
        async.elapse(const Duration(seconds: 1));
        expect(ticker.isTicking, isTrue);
        expect(values.length, greaterThanOrEqualTo(5));

        sub.cancel();
        async.flushMicrotasks();
        expect(ticker.isActive, isFalse);
        expect(ticker.isTicking, isFalse);
        expect(events.hasListener, isFalse);
        ticker.dispose();
      });
    });

    test('does not tick while the player is paused', () {
      fakeAsync((async) {
        setUpTicker(async);
        playing = false;
        var values = <Duration>[];
        var sub = ticker.stream.listen(values.add);
        async.elapse(const Duration(seconds: 1));
        expect(ticker.isTicking, isFalse);
        expect(values, [Duration.zero]);

        playing = true;
        events.add(null);
        async.elapse(const Duration(seconds: 1));
        expect(ticker.isTicking, isTrue);
        sub.cancel();
        ticker.dispose();
      });
    });

    test('stops in the background and catches up on resume', () {
      fakeAsync((async) {
        setUpTicker(async);
        var values = <Duration>[];
        var sub = ticker.stream.listen(values.add);
        async.elapse(const Duration(seconds: 1));

        ticker.setForeground(false);
        async.flushMicrotasks();
        var countWhenHidden = values.length;
        expect(ticker.isActive, isFalse);
        expect(ticker.isTicking, isFalse);
        expect(events.hasListener, isFalse);

        // Music keeps playing in the background, but nothing is emitted.
        async.elapse(const Duration(minutes: 1));
        expect(values.length, countWhenHidden);

        ticker.setForeground(true);
        async.flushMicrotasks();
        expect(values.length, countWhenHidden + 1);
        expect(values.last, position);
        expect(ticker.isTicking, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(values.length, greaterThan(countWhenHidden + 1));
        sub.cancel();
        ticker.dispose();
      });
    });

    test('a listener added while backgrounded does not start ticking', () {
      fakeAsync((async) {
        setUpTicker(async);
        ticker.setForeground(false);
        var sub = ticker.stream.listen((_) {});
        async.elapse(const Duration(seconds: 1));
        expect(ticker.isActive, isFalse);
        expect(events.hasListener, isFalse);
        sub.cancel();
        ticker.dispose();
      });
    });
  });
}
