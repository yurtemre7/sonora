import 'dart:convert';
import 'dart:typed_data';

/// Builders for tiny synthetic audio files carrying ReplayGain tags.

List<int> _be32(int v) => [
  v >> 24 & 0xFF,
  v >> 16 & 0xFF,
  v >> 8 & 0xFF,
  v & 0xFF,
];

List<int> _le32(int v) => [
  v & 0xFF,
  v >> 8 & 0xFF,
  v >> 16 & 0xFF,
  v >> 24 & 0xFF,
];

List<int> _syncsafe(int v) => [
  v >> 21 & 0x7F,
  v >> 14 & 0x7F,
  v >> 7 & 0x7F,
  v & 0x7F,
];

/// A TXXX payload with the given text [encoding] (0-3).
List<int> txxxPayload(String description, String value, {int encoding = 0}) {
  List<int> text(String s) => switch (encoding) {
    0 => latin1.encode(s),
    1 => [
      0xFF,
      0xFE,
      for (var c in s.codeUnits) ...[c & 0xFF, c >> 8],
    ],
    2 => [
      for (var c in s.codeUnits) ...[c >> 8, c & 0xFF],
    ],
    _ => utf8.encode(s),
  };
  var terminator = encoding == 1 || encoding == 2 ? [0, 0] : [0];
  return [encoding, ...text(description), ...terminator, ...text(value)];
}

/// An ID3v2.3 or v2.4 frame.
List<int> id3Frame(String id, List<int> payload, {int major = 3}) => [
  ...ascii.encode(id),
  ...(major == 4 ? _syncsafe(payload.length) : _be32(payload.length)),
  0,
  0,
  ...payload,
];

/// An ID3v2 tag holding [frames], followed by a fake MPEG frame header.
/// With [unsync], the whole tag body is unsynchronised (v2.3 style).
Uint8List id3Tag(
  List<List<int>> frames, {
  int major = 3,
  List<int>? extendedHeader,
  int padding = 16,
  bool unsync = false,
}) {
  var body = [
    ...?extendedHeader,
    for (var f in frames) ...f,
    ...List.filled(padding, 0),
  ];
  if (unsync) {
    body = [
      for (var b in body) ...(b == 0xFF ? [0xFF, 0x00] : [b]),
    ];
  }
  var flags = (extendedHeader != null ? 0x40 : 0) | (unsync ? 0x80 : 0);
  return Uint8List.fromList([
    ...ascii.encode('ID3'),
    major,
    0,
    flags,
    ..._syncsafe(body.length),
    ...body,
    0xFF,
    0xFB,
    0x90,
    0x00,
  ]);
}

/// A Vorbis comment block body (vendor + comments).
List<int> vorbisComment(List<String> comments) {
  var vendor = utf8.encode('test vendor');
  return [
    ..._le32(vendor.length),
    ...vendor,
    ..._le32(comments.length),
    for (var c in comments) ...[
      ..._le32(utf8.encode(c).length),
      ...utf8.encode(c),
    ],
  ];
}

/// A FLAC stream with STREAMINFO, a PICTURE block and a VORBIS_COMMENT block.
Uint8List flacFile(List<String> comments, {int pictureBytes = 2048}) {
  List<int> block(int type, List<int> data, {bool last = false}) => [
    (last ? 0x80 : 0) | type,
    data.length >> 16 & 0xFF,
    data.length >> 8 & 0xFF,
    data.length & 0xFF,
    ...data,
  ];
  return Uint8List.fromList([
    ...ascii.encode('fLaC'),
    ...block(0, List.filled(34, 0)),
    ...block(6, List.filled(pictureBytes, 7)),
    ...block(4, vorbisComment(comments), last: true),
  ]);
}

/// One Ogg page holding [packet] (which may be continued on later pages).
List<int> oggPage(List<int> data, {int serial = 0x1234, int sequence = 0}) {
  var lacing = <int>[];
  var remaining = data.length;
  while (remaining >= 255) {
    lacing.add(255);
    remaining -= 255;
  }
  lacing.add(remaining);
  return [
    ...ascii.encode('OggS'),
    0,
    sequence == 0 ? 2 : 0,
    ...List.filled(8, 0),
    ..._le32(serial),
    ..._le32(sequence),
    ...List.filled(4, 0), // CRC is not checked by the reader
    lacing.length,
    ...lacing,
    ...data,
  ];
}

/// An Ogg Opus file with the given comments. The comment packet is split
/// over pages of at most [maxPageData] bytes.
Uint8List opusFile(List<String> comments, {int maxPageData = 60000}) {
  var head = [
    ...ascii.encode('OpusHead'),
    1,
    2,
    0x38,
    0x01,
    ..._le32(48000),
    0,
    0,
    0,
  ];
  var tags = [...ascii.encode('OpusTags'), ...vorbisComment(comments)];
  var sequence = 1;
  return Uint8List.fromList([
    ...oggPage(head),
    for (var start = 0; start < tags.length; start += maxPageData)
      ...oggPage(
        tags.sublist(start, (start + maxPageData).clamp(0, tags.length)),
        sequence: sequence++,
      ),
    ...oggPage(List.filled(100, 0), sequence: sequence),
  ]);
}

/// An Ogg Vorbis file with the given comments.
Uint8List vorbisFile(List<String> comments) {
  return Uint8List.fromList([
    ...oggPage([1, ...ascii.encode('vorbis'), ...List.filled(23, 0)]),
    ...oggPage([
      3,
      ...ascii.encode('vorbis'),
      ...vorbisComment(comments),
      1, // framing bit
    ], sequence: 1),
  ]);
}

List<int> mp4Atom(String type, List<int> data) => [
  ..._be32(data.length + 8),
  ...latin1.encode(type),
  ...data,
];

/// An iTunes freeform ("----") metadata item.
List<int> mp4Freeform(String name, String value) => mp4Atom('----', [
  ...mp4Atom('mean', [0, 0, 0, 0, ...ascii.encode('com.apple.iTunes')]),
  ...mp4Atom('name', [0, 0, 0, 0, ...ascii.encode(name)]),
  ...mp4Atom('data', [0, 0, 0, 1, 0, 0, 0, 0, ...utf8.encode(value)]),
]);

/// An M4A file whose metadata holds [items].
Uint8List mp4File(List<List<int>> items) {
  return Uint8List.fromList([
    ...mp4Atom('ftyp', [...ascii.encode('M4A '), 0, 0, 0, 0]),
    ...mp4Atom('mdat', List.filled(4096, 0)),
    ...mp4Atom('moov', [
      ...mp4Atom('mvhd', List.filled(100, 0)),
      ...mp4Atom('udta', [
        ...mp4Atom('meta', [
          0,
          0,
          0,
          0,
          ...mp4Atom('hdlr', List.filled(25, 0)),
          ...mp4Atom('ilst', [
            ...mp4Atom('©nam', [
              ...mp4Atom('data', [
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                ...ascii.encode('T'),
              ]),
            ]),
            for (var item in items) ...item,
          ]),
        ]),
      ]),
    ]),
  ]);
}
