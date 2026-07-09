import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/song.dart';

void main() {
  test('Song model duration formatted correctly', () {
    var song1 = Song(
      id: 1,
      title: 'Test Song',
      artist: 'Test Artist',
      album: 'Test Album',
      duration: const Duration(minutes: 3, seconds: 45),
      filePath: '/path/to/song.mp3',
    );

    var song2 = Song(
      id: 2,
      title: 'Short Song',
      artist: 'Test Artist',
      album: 'Test Album',
      duration: const Duration(seconds: 5),
      filePath: '/path/to/song2.mp3',
    );

    expect(song1.durationFormatted, '3:45');
    expect(song2.durationFormatted, '0:05');
  });
}
