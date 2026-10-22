import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/replay_gain.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/replay_gain_reader.dart';

import 'helpers/replay_gain_fixtures.dart';

void main() {
  group('ReplayGainReader ID3v2', () {
    test('reads TXXX gains and peaks from ID3v2.3', () {
      var bytes = id3Tag([
        id3Frame('TIT2', [0, ...'Title'.codeUnits]),
        id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-7.43 dB')),
        id3Frame('TXXX', txxxPayload('replaygain_album_gain', '-6.10 dB')),
        id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_PEAK', '0.988525')),
      ]);

      var info = ReplayGainReader.readBytes(bytes)!;

      expect(info.trackGain, closeTo(-7.43, 1e-9));
      expect(info.albumGain, closeTo(-6.10, 1e-9));
      expect(info.trackPeak, closeTo(0.988525, 1e-9));
      expect(info.albumPeak, isNull);
    });

    test('reads every text encoding', () {
      for (var encoding in [0, 1, 2, 3]) {
        var bytes = id3Tag([
          id3Frame(
            'TXXX',
            txxxPayload(
              'REPLAYGAIN_TRACK_GAIN',
              '+1.50 dB',
              encoding: encoding,
            ),
          ),
        ]);
        expect(
          ReplayGainReader.readBytes(bytes)?.trackGain,
          1.5,
          reason: 'encoding $encoding',
        );
      }
    });

    test('reads ID3v2.4 syncsafe frames after an extended header and art', () {
      var bytes = id3Tag(
        [
          id3Frame('APIC', List.filled(40000, 0xFF), major: 4),
          id3Frame(
            'TXXX',
            txxxPayload('REPLAYGAIN_ALBUM_GAIN', '-9.5 dB', encoding: 3),
            major: 4,
          ),
        ],
        major: 4,
        extendedHeader: [0, 0, 0, 6, 1, 0],
      );

      var info = ReplayGainReader.readBytes(bytes)!;

      expect(info.trackGain, isNull);
      expect(info.albumGain, -9.5);
    });

    test('reads gains past the first block when reading from a file', () {
      var dir = Directory.systemTemp.createTempSync('sonora_rg_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      var file = File('${dir.path}/song.mp3')
        ..writeAsBytesSync(
          id3Tag([
            id3Frame('APIC', List.filled(70000, 1)),
            id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-3.2 dB')),
          ]),
        );

      expect(ReplayGainReader.readFile(file.path)?.trackGain, -3.2);
      expect(ReplayGainReader.readFile('${dir.path}/missing.mp3'), isNull);
    });

    test('decodes an unsynchronised ID3v2.3 tag', () {
      var bytes = id3Tag([
        id3Frame('APIC', List.filled(300, 0xFF)),
        id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-2.5 dB')),
      ], unsync: true);
      expect(ReplayGainReader.readBytes(bytes)?.trackGain, -2.5);
    });

    test('returns null for a tag without ReplayGain frames', () {
      var bytes = id3Tag([
        id3Frame('TXXX', txxxPayload('MusicBrainz Album Id', 'abc')),
      ]);
      expect(ReplayGainReader.readBytes(bytes), isNull);
    });
  });

  group('ReplayGainReader other formats', () {
    test('reads FLAC Vorbis comments past a picture block', () {
      var bytes = flacFile([
        'TITLE=Song',
        'REPLAYGAIN_TRACK_GAIN=-8.21 dB',
        'REPLAYGAIN_TRACK_PEAK=1.023',
        'REPLAYGAIN_ALBUM_GAIN=-7.00 dB',
        'REPLAYGAIN_ALBUM_PEAK=1.05',
      ]);

      var info = ReplayGainReader.readBytes(bytes)!;

      expect(info.trackGain, -8.21);
      expect(info.trackPeak, 1.023);
      expect(info.albumGain, -7.0);
      expect(info.albumPeak, 1.05);
    });

    test('converts Opus R128 gains to the ReplayGain reference', () {
      var bytes = opusFile([
        'TITLE=Song',
        'R128_TRACK_GAIN=-2560',
        'R128_ALBUM_GAIN=512',
      ]);

      var info = ReplayGainReader.readBytes(bytes)!;

      expect(info.trackGain, -5.0); // -10 dB re -23 LUFS, +5 dB
      expect(info.albumGain, 7.0);
      expect(info.trackPeak, isNull);
    });

    test('reads a comment header that spans several Ogg pages', () {
      var bytes = opusFile([
        'METADATA_BLOCK_PICTURE=${'A' * 3000}',
        'R128_TRACK_GAIN=256',
      ], maxPageData: 1000);
      expect(ReplayGainReader.readBytes(bytes)?.trackGain, 6.0);
    });

    test('reads Ogg Vorbis ReplayGain comments', () {
      var bytes = vorbisFile(['replaygain_track_gain=-4.00 dB']);
      expect(ReplayGainReader.readBytes(bytes)?.trackGain, -4.0);
    });

    test('ignores R128 tags outside Opus', () {
      var bytes = vorbisFile(['R128_TRACK_GAIN=-2560']);
      expect(ReplayGainReader.readBytes(bytes), isNull);
    });

    test('reads MP4 freeform iTunes atoms', () {
      var bytes = mp4File([
        mp4Freeform('replaygain_track_gain', '-6.53 dB'),
        mp4Freeform('replaygain_album_gain', '-5.80 dB'),
        mp4Freeform('replaygain_track_peak', '0.9'),
      ]);

      var info = ReplayGainReader.readBytes(bytes)!;

      expect(info.trackGain, -6.53);
      expect(info.albumGain, -5.8);
      expect(info.trackPeak, 0.9);
    });

    test('returns null for garbage and truncated input', () {
      var random = math.Random(42);
      var inputs = <Uint8List>[
        Uint8List(0),
        Uint8List.fromList('ID3'.codeUnits),
        Uint8List.fromList(List.generate(512, (_) => random.nextInt(256))),
        Uint8List.sublistView(
          id3Tag([
            id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-1 dB')),
          ]),
          0,
          20,
        ),
        Uint8List.sublistView(flacFile(['REPLAYGAIN_TRACK_GAIN=-1 dB']), 0, 60),
        Uint8List.sublistView(opusFile(['R128_TRACK_GAIN=1']), 0, 40),
        Uint8List.sublistView(
          mp4File([mp4Freeform('replaygain_track_gain', '-1 dB')]),
          0,
          200,
        ),
        flacFile(['REPLAYGAIN_TRACK_GAIN=loud']),
      ];
      for (var input in inputs) {
        expect(ReplayGainReader.readBytes(input), isNull);
      }
    });

    test('parses gain strings', () {
      expect(ReplayGainReader.parseGain('-7.43 dB'), -7.43);
      expect(ReplayGainReader.parseGain('+2,5 dB'), 2.5);
      expect(ReplayGainReader.parseGain(' 3 '), 3.0);
      expect(ReplayGainReader.parseGain('dB'), isNull);
      expect(ReplayGainReader.parseGain('-999 dB'), isNull);
    });
  });

  group('ReplayGain multiplier', () {
    const info = ReplayGainInfo(trackGain: -6.0, albumGain: -3.0);

    test('is 1.0 when off or untagged', () {
      expect(replayGainMultiplier(info, ReplayGainMode.off), 1.0);
      expect(replayGainMultiplier(null, ReplayGainMode.track), 1.0);
    });

    test('converts dB to a linear factor per mode', () {
      expect(
        replayGainMultiplier(info, ReplayGainMode.track),
        closeTo(math.pow(10, -6 / 20), 1e-9),
      );
      expect(
        replayGainMultiplier(info, ReplayGainMode.album),
        closeTo(math.pow(10, -3 / 20), 1e-9),
      );
    });

    test('album mode falls back to the track gain', () {
      const trackOnly = ReplayGainInfo(trackGain: -6.0);
      expect(
        replayGainMultiplier(trackOnly, ReplayGainMode.album),
        closeTo(math.pow(10, -6 / 20), 1e-9),
      );
    });

    test('a known peak caps positive gains to avoid clipping', () {
      const loud = ReplayGainInfo(trackGain: 6.0, trackPeak: 0.8);
      expect(replayGainMultiplier(loud, ReplayGainMode.track), 1 / 0.8);
      const noPeak = ReplayGainInfo(trackGain: 6.0);
      expect(
        replayGainMultiplier(noPeak, ReplayGainMode.track),
        closeTo(math.pow(10, 6 / 20), 1e-9),
      );
    });

    test('player volume is capped at 1.0', () {
      expect(effectiveReplayGainVolume(0.5, 0.5), 0.25);
      expect(effectiveReplayGainVolume(0.8, 2.0), 1.0);
      expect(effectiveReplayGainVolume(0.0, 2.0), 0.0);
    });

    test('mode round-trips through storage', () {
      for (var mode in ReplayGainMode.values) {
        expect(ReplayGainMode.fromStorage(mode.name), mode);
      }
      expect(ReplayGainMode.fromStorage(null), ReplayGainMode.off);
      expect(ReplayGainMode.fromStorage('bogus'), ReplayGainMode.off);
    });

    test('song extras carry gains to the audio handler', () {
      var song = Song(
        id: 1,
        title: 'T',
        artist: 'A',
        album: 'B',
        duration: Duration.zero,
        filePath: '/x.mp3',
      ).withReplayGain(const ReplayGainInfo(trackGain: -2, albumPeak: 0.7));

      var parsed = ReplayGainExtras.parse(song.replayGainExtras)!;

      expect(song.replayGainScanned, isTrue);
      expect(parsed.trackGain, -2);
      expect(parsed.albumPeak, 0.7);
      expect(parsed.albumGain, isNull);
      expect(ReplayGainExtras.parse(null), isNull);
      expect(song.withReplayGain(null).replayGainExtras, isNull);
    });
  });
}
