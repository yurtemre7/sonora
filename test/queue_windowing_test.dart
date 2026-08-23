import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/song.dart';

void main() {
  group('Queue Windowing & Numbering Logic', () {
    List<Song> createMockQueue(int count) {
      return List.generate(
        count,
        (i) => Song(
          id: i + 1,
          title: 'Song ${i + 1}',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          filePath: '/mock/song_${i + 1}.mp3',
        ),
      );
    }

    test('Queue at start (index 0 / item 1) starts window at offset 0', () {
      var queue = createMockQueue(200);
      var currentIndex = 0;
      var safeCurrentIndex = (currentIndex >= 0 && currentIndex < queue.length)
          ? currentIndex
          : 0;
      var displayOffset = safeCurrentIndex > 0 ? safeCurrentIndex - 1 : 0;
      var displayQueue = queue.sublist(displayOffset);

      expect(displayOffset, equals(0));
      expect(displayQueue.length, equals(200));
      expect(displayQueue[0].id, equals(1)); // First song is 1
    });

    test('Queue at item 100/200 (index 99) windows at offset 98 (item 99)', () {
      var queue = createMockQueue(200);
      var currentIndex = 99; // 100th song
      var safeCurrentIndex = (currentIndex >= 0 && currentIndex < queue.length)
          ? currentIndex
          : 0;
      var displayOffset = safeCurrentIndex > 0 ? safeCurrentIndex - 1 : 0;
      var displayQueue = queue.sublist(displayOffset);

      expect(displayOffset, equals(98));
      expect(displayQueue.length, equals(102)); // 99..200 is 102 items

      // First displayed item is song 99 (index 98 in queue)
      var firstDisplayedActualIndex = 0 + displayOffset;
      expect(firstDisplayedActualIndex, equals(98));
      expect(displayQueue[0].id, equals(99));
      expect(firstDisplayedActualIndex + 1, equals(99)); // Item #99

      // Second displayed item is song 100 (index 99 in queue, current)
      var currentDisplayedActualIndex = 1 + displayOffset;
      expect(currentDisplayedActualIndex, equals(99));
      expect(displayQueue[1].id, equals(100));
      expect(currentDisplayedActualIndex + 1, equals(100)); // Item #100

      // Last displayed item is song 200 (index 199 in queue)
      var lastDisplayedActualIndex = (displayQueue.length - 1) + displayOffset;
      expect(lastDisplayedActualIndex, equals(199));
      expect(displayQueue.last.id, equals(200));
      expect(lastDisplayedActualIndex + 1, equals(200)); // Item #200
    });

    test('Skipping back from item 100 (index 99) to item 99 (index 98) shifts window by 1', () {
      var queue = createMockQueue(200);
      var currentIndex = 98; // Tapped item 99
      var safeCurrentIndex = (currentIndex >= 0 && currentIndex < queue.length)
          ? currentIndex
          : 0;
      var displayOffset = safeCurrentIndex > 0 ? safeCurrentIndex - 1 : 0;
      var displayQueue = queue.sublist(displayOffset);

      expect(displayOffset, equals(97));
      expect(displayQueue.length, equals(103)); // 98..200 is 103 items
      expect(displayQueue[0].id, equals(98)); // Shows item 98
      expect(displayQueue[1].id, equals(99)); // Shows item 99 (current)
    });

    test('Number width dynamically scales and clamps correctly', () {
      double computeWidth(int queueLength) {
        var numDigits = queueLength.toString().length;
        return (numDigits * 9.0 + 16.0).clamp(32.0, 52.0);
      }

      expect(computeWidth(5), equals(32.0)); // 1 digit: 25 -> clamped to 32
      expect(computeWidth(50), equals(34.0)); // 2 digits: 34
      expect(computeWidth(200), equals(43.0)); // 3 digits: 43
      expect(computeWidth(2000), equals(52.0)); // 4 digits: 52
      expect(computeWidth(50000), equals(52.0)); // 5 digits: clamped to 52
    });
  });
}
