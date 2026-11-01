part of 'music_scanner.dart';

/// Adding music on platforms where the scanner can only read the app's own
/// sandbox (iOS).
extension ScannerImport on MusicScanner {
  static const _importExtensions = ['mp3', 'm4a', 'aac', 'flac', 'wav'];

  /// Lets the user pick audio files and copies them into the scan folder.
  /// Files that already exist there are left alone.
  /// Returns the scan folder, or null when nothing was picked.
  Future<String?> pickAudioFilesIntoLibrary() async {
    var folder = await getScanFolder();
    if (folder == null) return null;

    var picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _importExtensions,
    );
    if (picked.isEmpty) return null;

    for (var file in picked) {
      var source = file.path;
      if (source == null) continue;
      var target = File('$folder/${file.name}');
      if (!target.existsSync()) await File(source).copy(target.path);
    }
    return folder;
  }
}
