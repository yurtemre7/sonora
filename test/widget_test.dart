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

  test(
    'Song model displayTitle cleans up featuring artist details and redundant artist names',
    () {
      // 1. Basic featuring removal in parentheses/brackets
      var songFt1 = Song(
        id: 1,
        title: 'Beautiful Life (feat. Jane Doe)',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songFt1.displayTitle, 'Beautiful Life');

      var songFt2 = Song(
        id: 2,
        title: 'Beautiful Life [ft. Jane Doe]',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songFt2.displayTitle, 'Beautiful Life');

      var songFt3 = Song(
        id: 3,
        title: 'Beautiful Life (featuring Jane Doe)',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songFt3.displayTitle, 'Beautiful Life');

      // 2. Case-insensitivity check
      var songFtCase = Song(
        id: 4,
        title: 'Beautiful Life (FEAT. Jane Doe)',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songFtCase.displayTitle, 'Beautiful Life');

      // 3. Keep original title if it has no featuring
      var songNormal = Song(
        id: 5,
        title: 'Beautiful Life',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songNormal.displayTitle, 'Beautiful Life');

      // 4. Redundant artist name removal combined with featuring removal
      var songRedundant = Song(
        id: 6,
        title: 'John Smith - Beautiful Life (feat. Jane Doe)',
        artist: 'John Smith',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: 'path.mp3',
      );
      expect(songRedundant.displayTitle, 'Beautiful Life');
    },
  );
}
