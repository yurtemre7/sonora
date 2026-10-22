import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sonora/models/replay_gain.dart';

/// Reads ReplayGain tags from audio files without decoding them.
///
/// Only tag headers are read: frames, blocks and atoms that cannot hold
/// ReplayGain values (artwork, audio data) are skipped by offset, never
/// loaded. Supports ID3v2 (MP3), FLAC, Ogg Vorbis/Opus and MP4/M4A. Any
/// unknown format, missing tag or malformed data yields `null`; the reader
/// never throws.
abstract final class ReplayGainReader {
  /// Reads the ReplayGain values of the file at [path], or `null`.
  static ReplayGainInfo? readFile(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      return _read(_FileSource(file));
    } catch (_) {
      return null;
    } finally {
      try {
        file?.closeSync();
      } catch (_) {}
    }
  }

  /// Reads the ReplayGain values of an in-memory file, or `null`.
  static ReplayGainInfo? readBytes(Uint8List bytes) {
    try {
      return _read(_BytesSource(bytes));
    } catch (_) {
      return null;
    }
  }

  /// Parses a gain value such as "-7.43 dB" into dB, or `null`.
  static double? parseGain(String value) {
    var match = RegExp(r'^\s*([+-]?\d+(?:[.,]\d+)?)').firstMatch(value);
    if (match == null) return null;
    var gain = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (gain == null || !gain.isFinite || gain.abs() > 60) return null;
    return gain;
  }

  /// Parses a linear peak value such as "0.988525", or `null`.
  static double? parsePeak(String value) {
    var peak = double.tryParse(value.trim().replaceAll(',', '.'));
    if (peak == null || !peak.isFinite || peak <= 0 || peak > 10) return null;
    return peak;
  }

  static ReplayGainInfo? _read(_Source source) {
    var magic = source.read(0, 12);
    if (magic == null) return null;

    if (_matches(magic, 0, 'ID3')) {
      var tags = _Tags();
      var tagEnd = _readId3v2(source, tags);
      if (tags.result != null) return tags.result;
      // Some FLAC files carry a leading ID3v2 tag before the stream marker.
      if (tagEnd != null) {
        var next = source.read(tagEnd, 4);
        if (next != null && _matches(next, 0, 'fLaC')) {
          return _readFlac(source, tagEnd + 4);
        }
      }
      return null;
    }
    if (_matches(magic, 0, 'fLaC')) return _readFlac(source, 4);
    if (_matches(magic, 0, 'OggS')) return _readOgg(source);
    if (_matches(magic, 4, 'ftyp')) return _readMp4(source);
    return null;
  }

  // ---------------------------------------------------------------------------
  // ID3v2
  // ---------------------------------------------------------------------------

  /// Parses an ID3v2 tag at offset 0 into [tags]. Returns the offset just past
  /// the tag, or `null` when the header is invalid.
  static int? _readId3v2(_Source source, _Tags tags) {
    var header = source.read(0, 10);
    if (header == null) return null;
    var major = header[3];
    var flags = header[5];
    var tagSize = _syncsafe(header, 6);
    if (tagSize == null || major < 2 || major > 4) return null;
    var tagEnd = 10 + tagSize;
    if (major == 4 && flags & 0x10 != 0) tagEnd += 10; // footer

    var tagUnsync = flags & 0x80 != 0;
    var hasExtendedHeader = flags & 0x40 != 0;

    // In v2.2/v2.3, unsynchronisation covers the whole tag (frame sizes refer
    // to the decoded data), so the tag is decoded up front with a size cap.
    if (tagUnsync && major < 4) {
      var length = (tagSize).clamp(0, _maxUnsyncTagBytes);
      var raw = source.read(10, length) ?? source.read(10, source.length - 10);
      if (raw == null) return tagEnd;
      var decoded = _BytesSource(_removeUnsync(raw));
      _readId3Frames(
        decoded,
        0,
        decoded.length,
        major,
        hasExtendedHeader,
        false,
        tags,
      );
      return tagEnd;
    }

    _readId3Frames(
      source,
      10,
      10 + tagSize,
      major,
      hasExtendedHeader,
      tagUnsync,
      tags,
    );
    return tagEnd;
  }

  static void _readId3Frames(
    _Source source,
    int start,
    int end,
    int major,
    bool hasExtendedHeader,
    bool unsyncAllFrames,
    _Tags tags,
  ) {
    var pos = start;
    if (hasExtendedHeader && major >= 3) {
      var ext = source.read(pos, 4);
      if (ext == null) return;
      if (major == 4) {
        var size = _syncsafe(ext, 0);
        if (size == null || size < 6) return;
        pos += size;
      } else {
        pos += 4 + _uint32(ext, 0);
      }
    }

    var idLength = major == 2 ? 3 : 4;
    var headerLength = major == 2 ? 6 : 10;
    var frames = 0;
    while (pos + headerLength <= end && frames++ < _maxFrames) {
      var header = source.read(pos, headerLength);
      if (header == null || header[0] == 0) return; // padding
      var id = String.fromCharCodes(header, 0, idLength);
      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(id)) return;

      int size;
      var formatFlags = 0;
      if (major == 2) {
        size = header[3] << 16 | header[4] << 8 | header[5];
      } else if (major == 4) {
        // Some writers store plain sizes in v2.4; a high bit gives them away.
        size = _syncsafe(header, 4) ?? _uint32(header, 4);
        formatFlags = header[9];
      } else {
        size = _uint32(header, 4);
        formatFlags = header[9];
      }
      var dataStart = pos + headerLength;
      pos = dataStart + size;
      if (size <= 0 || pos > end) return;

      if (id != 'TXXX' && id != 'TXX') continue;
      if (size > _maxTextFrameBytes) continue;

      var skip = 0;
      var frameUnsync = unsyncAllFrames;
      if (major == 3) {
        if (formatFlags & 0xC0 != 0) continue; // compressed or encrypted
        if (formatFlags & 0x20 != 0) skip += 1; // grouping identity
      } else if (major == 4) {
        if (formatFlags & 0x0C != 0) continue; // compressed or encrypted
        if (formatFlags & 0x40 != 0) skip += 1; // grouping identity
        if (formatFlags & 0x01 != 0) skip += 4; // data length indicator
        if (formatFlags & 0x02 != 0) frameUnsync = true;
      }
      if (skip >= size) continue;

      var data = source.read(dataStart + skip, size - skip);
      if (data == null) return;
      if (frameUnsync) data = _removeUnsync(data);
      var pair = _parseTxxx(data);
      if (pair != null) tags.add(pair.$1, pair.$2);
    }
  }

  /// Splits a TXXX payload into its description and value.
  static (String, String)? _parseTxxx(Uint8List data) {
    if (data.isEmpty) return null;
    var encoding = data[0];
    if (encoding > 3) return null;
    var wide = encoding == 1 || encoding == 2;
    var descriptionEnd = _findTerminator(data, 1, wide);
    var description = _decodeText(data.sublist(1, descriptionEnd), encoding);
    var valueStart = descriptionEnd + (wide ? 2 : 1);
    if (valueStart > data.length) return null;
    var valueBytes = data.sublist(valueStart);
    var valueEnd = _findTerminator(valueBytes, 0, wide);
    var value = _decodeText(valueBytes.sublist(0, valueEnd), encoding);
    return (description, value);
  }

  static int _findTerminator(Uint8List data, int start, bool wide) {
    if (!wide) {
      for (var i = start; i < data.length; i++) {
        if (data[i] == 0) return i;
      }
      return data.length;
    }
    for (var i = start; i + 1 < data.length; i += 2) {
      if (data[i] == 0 && data[i + 1] == 0) return i;
    }
    return data.length;
  }

  static String _decodeText(Uint8List bytes, int encoding) {
    switch (encoding) {
      case 0:
        return latin1.decode(bytes);
      case 3:
        return utf8.decode(bytes, allowMalformed: true);
      default:
        var bigEndian = encoding == 2;
        var start = 0;
        if (encoding == 1 && bytes.length >= 2) {
          if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
            start = 2;
          } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
            bigEndian = true;
            start = 2;
          }
        }
        var units = <int>[];
        for (var i = start; i + 1 < bytes.length; i += 2) {
          units.add(
            bigEndian
                ? bytes[i] << 8 | bytes[i + 1]
                : bytes[i + 1] << 8 | bytes[i],
          );
        }
        return String.fromCharCodes(units);
    }
  }

  /// Reverses ID3 unsynchronisation (0xFF 0x00 → 0xFF).
  static Uint8List _removeUnsync(Uint8List data) {
    var out = BytesBuilder(copy: false);
    for (var i = 0; i < data.length; i++) {
      out.addByte(data[i]);
      if (data[i] == 0xFF && i + 1 < data.length && data[i + 1] == 0) i++;
    }
    return out.toBytes();
  }

  // ---------------------------------------------------------------------------
  // FLAC
  // ---------------------------------------------------------------------------

  static ReplayGainInfo? _readFlac(_Source source, int start) {
    var pos = start;
    for (var blocks = 0; blocks < _maxFrames; blocks++) {
      var header = source.read(pos, 4);
      if (header == null) return null;
      var isLast = header[0] & 0x80 != 0;
      var type = header[0] & 0x7F;
      var length = header[1] << 16 | header[2] << 8 | header[3];
      var dataStart = pos + 4;
      if (type == 4) {
        var tags = _Tags();
        _readVorbisComments(
          _RangeStream(source, dataStart, dataStart + length),
          tags,
        );
        return tags.result;
      }
      if (isLast || type == 127) return null;
      pos = dataStart + length;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Ogg (Vorbis / Opus)
  // ---------------------------------------------------------------------------

  static ReplayGainInfo? _readOgg(_Source source) {
    var first = _OggPage.read(source, 0);
    if (first == null) return null;
    var head = source.read(first.dataStart, 8);
    if (head == null) return null;

    bool isOpus;
    if (_matches(head, 0, 'OpusHead')) {
      isOpus = true;
    } else if (head[0] == 1 && _matches(head, 1, 'vorbis')) {
      isOpus = false;
    } else {
      return null;
    }

    // The identification header sits alone on the first page; the comment
    // header starts on the next page of the same logical stream.
    var stream = _OggStream(source, first.end, first.serial);
    var magic = stream.read(isOpus ? 8 : 7);
    if (magic == null) return null;
    if (isOpus ? !_matches(magic, 0, 'OpusTags') : !_isVorbisComment(magic)) {
      return null;
    }

    var tags = _Tags(isOpus: isOpus);
    _readVorbisComments(stream, tags);
    return tags.result;
  }

  static bool _isVorbisComment(Uint8List magic) =>
      magic[0] == 3 && _matches(magic, 1, 'vorbis');

  // ---------------------------------------------------------------------------
  // Vorbis comments (FLAC and Ogg)
  // ---------------------------------------------------------------------------

  static void _readVorbisComments(_ByteStream stream, _Tags tags) {
    var vendorLength = stream.read(4);
    if (vendorLength == null) return;
    if (!stream.skip(_uint32le(vendorLength, 0))) return;
    var countBytes = stream.read(4);
    if (countBytes == null) return;
    var count = _uint32le(countBytes, 0);
    for (var i = 0; i < count && i < _maxComments; i++) {
      var lengthBytes = stream.read(4);
      if (lengthBytes == null) return;
      var length = _uint32le(lengthBytes, 0);
      if (length > _maxCommentBytes) {
        if (!stream.skip(length)) return;
        continue;
      }
      var comment = stream.read(length);
      if (comment == null) return;
      var text = utf8.decode(comment, allowMalformed: true);
      var eq = text.indexOf('=');
      if (eq > 0) tags.add(text.substring(0, eq), text.substring(eq + 1));
    }
  }

  // ---------------------------------------------------------------------------
  // MP4 / M4A
  // ---------------------------------------------------------------------------

  static ReplayGainInfo? _readMp4(_Source source) {
    var moov = _findAtom(source, 0, source.length, 'moov');
    if (moov == null) return null;
    var udta = _findAtom(source, moov.dataStart, moov.end, 'udta');
    if (udta == null) return null;
    var meta = _findAtom(source, udta.dataStart, udta.end, 'meta');
    if (meta == null) return null;

    // ISO 'meta' is a full box (4 version/flag bytes); QuickTime's is not.
    var metaChildren = meta.dataStart;
    var probe = source.read(meta.dataStart + 4, 4);
    if (probe != null && !_matches(probe, 0, 'hdlr')) metaChildren += 4;
    var ilst = _findAtom(source, metaChildren, meta.end, 'ilst');
    if (ilst == null) return null;

    var tags = _Tags();
    var pos = ilst.dataStart;
    for (var items = 0; items < _maxAtoms && pos < ilst.end; items++) {
      var item = _Atom.read(source, pos, ilst.end);
      if (item == null) break;
      pos = item.end;
      if (item.type != '----' ||
          item.end - item.dataStart > _maxTextFrameBytes) {
        continue;
      }
      _readFreeformAtom(source, item, tags);
    }
    return tags.result;
  }

  static void _readFreeformAtom(_Source source, _Atom item, _Tags tags) {
    String? mean;
    String? name;
    String? value;
    var pos = item.dataStart;
    for (var i = 0; i < 8 && pos < item.end; i++) {
      var child = _Atom.read(source, pos, item.end);
      if (child == null) return;
      pos = child.end;
      var skip = child.type == 'data' ? 8 : 4; // full box header / type+locale
      var length = child.end - child.dataStart - skip;
      if (length < 0) continue;
      var bytes = source.read(child.dataStart + skip, length);
      if (bytes == null) return;
      var text = utf8.decode(bytes, allowMalformed: true);
      switch (child.type) {
        case 'mean':
          mean = text;
        case 'name':
          name = text;
        case 'data':
          value ??= text;
      }
    }
    if (name == null || value == null) return;
    if (mean != null && mean != 'com.apple.iTunes') return;
    tags.add(name, value);
  }

  static _Atom? _findAtom(_Source source, int start, int end, String type) {
    var pos = start;
    for (var i = 0; i < _maxAtoms && pos < end; i++) {
      var atom = _Atom.read(source, pos, end);
      if (atom == null) return null;
      if (atom.type == type) return atom;
      pos = atom.end;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static const _maxFrames = 4096;
  static const _maxAtoms = 512;
  static const _maxComments = 1024;
  static const _maxTextFrameBytes = 4096;
  static const _maxCommentBytes = 1024;
  static const _maxUnsyncTagBytes = 1 << 20;

  static bool _matches(Uint8List bytes, int offset, String ascii) {
    if (offset + ascii.length > bytes.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (bytes[offset + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Decodes a 28-bit syncsafe integer, or `null` if a high bit is set.
  static int? _syncsafe(Uint8List b, int offset) {
    if ((b[offset] | b[offset + 1] | b[offset + 2] | b[offset + 3]) & 0x80 !=
        0) {
      return null;
    }
    return b[offset] << 21 |
        b[offset + 1] << 14 |
        b[offset + 2] << 7 |
        b[offset + 3];
  }

  static int _uint32(Uint8List b, int offset) =>
      b[offset] << 24 |
      b[offset + 1] << 16 |
      b[offset + 2] << 8 |
      b[offset + 3];

  static int _uint32le(Uint8List b, int offset) =>
      b[offset] |
      b[offset + 1] << 8 |
      b[offset + 2] << 16 |
      b[offset + 3] << 24;
}

/// Collects ReplayGain values from tag key/value pairs.
class _Tags {
  _Tags({this.isOpus = false});

  final bool isOpus;
  double? trackGain;
  double? albumGain;
  double? trackPeak;
  double? albumPeak;
  double? r128TrackGain;
  double? r128AlbumGain;

  void add(String key, String value) {
    switch (key.trim().toUpperCase()) {
      case 'REPLAYGAIN_TRACK_GAIN':
        trackGain ??= ReplayGainReader.parseGain(value);
      case 'REPLAYGAIN_ALBUM_GAIN':
        albumGain ??= ReplayGainReader.parseGain(value);
      case 'REPLAYGAIN_TRACK_PEAK':
        trackPeak ??= ReplayGainReader.parsePeak(value);
      case 'REPLAYGAIN_ALBUM_PEAK':
        albumPeak ??= ReplayGainReader.parsePeak(value);
      case 'R128_TRACK_GAIN':
        if (isOpus) r128TrackGain ??= _parseR128(value);
      case 'R128_ALBUM_GAIN':
        if (isOpus) r128AlbumGain ??= _parseR128(value);
    }
  }

  /// R128 gains are Q7.8 integers relative to -23 LUFS; ReplayGain's reference
  /// is about 5 dB louder (-18 LUFS), so they convert with a +5 dB offset.
  static double? _parseR128(String value) {
    var raw = int.tryParse(value.trim());
    if (raw == null || raw < -32768 || raw > 32767) return null;
    return raw / 256 + 5;
  }

  ReplayGainInfo? get result {
    // Opus defines R128 tags; ReplayGain tags in Opus are a non-standard
    // fallback some taggers write anyway.
    var info = ReplayGainInfo(
      trackGain: r128TrackGain ?? trackGain,
      albumGain: r128AlbumGain ?? albumGain,
      trackPeak: r128TrackGain != null ? null : trackPeak,
      albumPeak: r128AlbumGain != null ? null : albumPeak,
    );
    return info.hasGain ? info : null;
  }
}

/// Random-access byte source. Reads return `null` when out of range.
abstract class _Source {
  int get length;
  Uint8List? read(int offset, int count);
}

class _BytesSource implements _Source {
  _BytesSource(this.bytes);

  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Uint8List? read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > bytes.length) return null;
    return Uint8List.sublistView(bytes, offset, offset + count);
  }
}

/// File source with a small block cache so many small header reads touch the
/// disk only a few times.
class _FileSource implements _Source {
  _FileSource(this.file) : length = file.lengthSync();

  static const _blockSize = 16 * 1024;
  static const _maxCachedBlocks = 4;

  final RandomAccessFile file;
  @override
  final int length;
  final _blocks = <int, Uint8List>{};

  @override
  Uint8List? read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > length) return null;
    if (count == 0) return Uint8List(0);
    if (count > _blockSize) {
      file.setPositionSync(offset);
      var data = file.readSync(count);
      return data.length == count ? data : null;
    }
    var out = Uint8List(count);
    var written = 0;
    while (written < count) {
      var position = offset + written;
      var index = position ~/ _blockSize;
      var block = _block(index);
      var inBlock = position - index * _blockSize;
      var take = (block.length - inBlock).clamp(0, count - written);
      if (take <= 0) return null;
      out.setRange(written, written + take, block, inBlock);
      written += take;
    }
    return out;
  }

  Uint8List _block(int index) {
    var cached = _blocks.remove(index);
    if (cached == null) {
      file.setPositionSync(index * _blockSize);
      cached = file.readSync(_blockSize);
      if (_blocks.length >= _maxCachedBlocks) {
        _blocks.remove(_blocks.keys.first);
      }
    }
    return _blocks[index] = cached;
  }
}

/// Sequential reader used by the Vorbis comment parser.
abstract class _ByteStream {
  Uint8List? read(int count);
  bool skip(int count);
}

class _RangeStream implements _ByteStream {
  _RangeStream(this.source, this.pos, this.end);

  final _Source source;
  int pos;
  final int end;

  @override
  Uint8List? read(int count) {
    if (pos + count > end) return null;
    var data = source.read(pos, count);
    pos += count;
    return data;
  }

  @override
  bool skip(int count) {
    pos += count;
    return pos <= end;
  }
}

class _OggPage {
  _OggPage(this.serial, this.dataStart, this.end);

  final int serial;
  final int dataStart;
  final int end;

  static _OggPage? read(_Source source, int offset) {
    var header = source.read(offset, 27);
    if (header == null || !ReplayGainReader._matches(header, 0, 'OggS')) {
      return null;
    }
    var serial = ReplayGainReader._uint32le(header, 14);
    var segments = header[26];
    var table = source.read(offset + 27, segments);
    if (table == null) return null;
    var dataLength = 0;
    for (var s in table) {
      dataLength += s;
    }
    var dataStart = offset + 27 + segments;
    return _OggPage(serial, dataStart, dataStart + dataLength);
  }
}

/// Reads the payload of consecutive Ogg pages of one stream as a byte stream.
class _OggStream implements _ByteStream {
  _OggStream(this.source, this._nextPage, this.serial);

  static const _maxPages = 512;

  final _Source source;
  final int serial;
  int _nextPage;
  var _pos = 0;
  var _end = 0;
  var _pages = 0;

  bool _advance() {
    while (_pages++ < _maxPages) {
      var page = _OggPage.read(source, _nextPage);
      if (page == null) return false;
      _nextPage = page.end;
      if (page.serial != serial) continue;
      _pos = page.dataStart;
      _end = page.end;
      return true;
    }
    return false;
  }

  @override
  Uint8List? read(int count) {
    var out = BytesBuilder(copy: false);
    var remaining = count;
    while (remaining > 0) {
      if (_pos >= _end && !_advance()) return null;
      var take = remaining < _end - _pos ? remaining : _end - _pos;
      var data = source.read(_pos, take);
      if (data == null) return null;
      out.add(data);
      _pos += take;
      remaining -= take;
    }
    return out.toBytes();
  }

  @override
  bool skip(int count) {
    var remaining = count;
    while (remaining > 0) {
      if (_pos >= _end && !_advance()) return false;
      var take = remaining < _end - _pos ? remaining : _end - _pos;
      _pos += take;
      remaining -= take;
    }
    return true;
  }
}

class _Atom {
  _Atom(this.type, this.dataStart, this.end);

  final String type;
  final int dataStart;
  final int end;

  static _Atom? read(_Source source, int offset, int limit) {
    var header = source.read(offset, 8);
    if (header == null) return null;
    var size = ReplayGainReader._uint32(header, 0);
    var type = latin1.decode(header.sublist(4, 8));
    var headerLength = 8;
    if (size == 1) {
      var large = source.read(offset + 8, 8);
      if (large == null) return null;
      size =
          ReplayGainReader._uint32(large, 0) * 0x100000000 +
          ReplayGainReader._uint32(large, 4);
      headerLength = 16;
    } else if (size == 0) {
      size = limit - offset;
    }
    if (size < headerLength || offset + size > limit) return null;
    return _Atom(type, offset + headerLength, offset + size);
  }
}
