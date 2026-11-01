// Regenerates CHANGELOG.md from the git history (conventional commits) and
// the version in pubspec.yaml. Run from the repository root:
//
//   dart run scripts/generate_changelog.dart
import 'dart:io';

class _Bucket {
  _Bucket(this.date);

  final String date;
  final added = <String>[];
  final fixed = <String>[];
  final changed = <String>[];
}

class _Commit {
  _Commit(this.date, this.subject);

  final String date;
  final String subject;
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

String _today() {
  var now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

String _pubspecVersion() {
  var file = File('pubspec.yaml');
  if (!file.existsSync()) return '';
  for (var line in file.readAsLinesSync()) {
    if (line.startsWith('version:')) {
      return line.split(':')[1].trim().split('+')[0];
    }
  }
  return '';
}

List<_Commit> _readCommits() {
  var result = Process.runSync('git', ['log', '--pretty=format:%h|%as|%s']);
  if (result.exitCode != 0) return [];
  var commits = <_Commit>[];
  for (var line in (result.stdout as String).trim().split('\n')) {
    var parts = line.split('|');
    if (parts.length < 3) continue;
    commits.add(_Commit(parts[1], parts.sublist(2).join('|')));
  }
  return commits;
}

/// Manually written bullets of existing sections, so they are not lost.
Map<String, ({String date, List<String> content})> _existingSections() {
  var file = File('CHANGELOG.md');
  if (!file.existsSync()) return {};

  var sections = <String, ({String date, List<String> content})>{};
  var header = RegExp(r'^##\s*\[([^\]]+)\](?:\s*-\s*(.*))?');
  String? current;
  for (var raw in file.readAsLinesSync()) {
    var line = raw.trim();
    var match = header.firstMatch(line);
    if (match != null) {
      current = match.group(1)!.trim();
      sections.putIfAbsent(
        current,
        () => (date: match.group(2)?.trim() ?? '', content: <String>[]),
      );
    } else if (current != null && line.startsWith('*')) {
      sections[current]!.content.add(line);
    }
  }
  return sections;
}

void main() {
  var pubVersion = _pubspecVersion();
  var existing = _existingSections();
  var today = _today();

  var release = RegExp(r'^release:\s*v?(\d+\.\d+\.\d+)', caseSensitive: false);
  var releaseText = RegExp(
    r'^release:\s*v?\d+\.\d+\.\d+(?:\+\d+)?(?:\s*-\s*|\s*:\s*|\s+)?',
    caseSensitive: false,
  );
  var conventional = RegExp(r'^(\w+)(?:\(([^)]+)\))?:\s*(.*)$');

  var buckets = <String, _Bucket>{};
  var currentVersion = pubVersion.isEmpty ? 'Unreleased' : pubVersion;
  buckets[currentVersion] = _Bucket(today);

  for (var commit in _readCommits()) {
    var subject = commit.subject;

    // A release commit closes the version above it and starts the next one.
    var releaseMatch = release.firstMatch(subject);
    if (releaseMatch != null) {
      var description = subject.replaceFirst(releaseText, '').trim();
      if (description.isNotEmpty && !RegExp(r'^\d+$').hasMatch(description)) {
        buckets[currentVersion]!.changed.add(_capitalize(description));
      }
      currentVersion = releaseMatch.group(1)!;
      buckets.putIfAbsent(currentVersion, () => _Bucket(commit.date));
      continue;
    }

    var bucket = buckets.putIfAbsent(currentVersion, () => _Bucket(commit.date));
    var match = conventional.firstMatch(subject);
    if (match != null) {
      var type = match.group(1)!.toLowerCase();
      var message = match.group(3)!.trim();
      if (message.isEmpty) continue;
      var text = _capitalize(message);

      if (type == 'feat') {
        bucket.added.add(text);
      } else if (type == 'fix') {
        bucket.fixed.add(text);
      } else if (const {
        'refactor',
        'style',
        'perf',
        'docs',
        'chore',
      }.contains(type)) {
        bucket.changed.add('${_capitalize(type)}: $text');
      } else {
        bucket.changed.add(text);
      }
    } else if (subject.isNotEmpty) {
      var lower = subject.toLowerCase();
      var text = _capitalize(subject);
      if (lower.startsWith('add') || lower.contains('implement')) {
        bucket.added.add(text);
      } else if (lower.startsWith('fix') || lower.contains('prevent')) {
        bucket.fixed.add(text);
      } else if (!lower.contains('merge branch') &&
          !lower.contains('bump version')) {
        bucket.changed.add(text);
      }
    }
  }

  var lines = <String>[
    '# Changelog\n',
    'All notable changes to the Sonora music player project are documented in this file.\n',
  ];

  var versions = [
    ...buckets.keys,
    for (var version in existing.keys)
      if (!buckets.containsKey(version) && version != 'Unreleased') version,
  ];

  for (var version in versions) {
    var bucket = buckets[version] ?? _Bucket(today);
    var manual = existing[version];
    var date = bucket.date.isNotEmpty
        ? bucket.date
        : (manual != null && manual.date.isNotEmpty ? manual.date : today);

    var added = bucket.added.toSet().toList();
    var fixed = bucket.fixed.toSet().toList();
    var changed = bucket.changed.toSet().toList();
    var manualBullets = manual?.content ?? const <String>[];

    if (added.isEmpty &&
        fixed.isEmpty &&
        changed.isEmpty &&
        manualBullets.isEmpty) {
      continue;
    }

    lines.add('## [$version] - $date');
    for (var (title, items) in [
      ('Added', added),
      ('Fixed', fixed),
      ('Changed', changed),
    ]) {
      if (items.isEmpty) continue;
      lines.add('### $title');
      lines.addAll(items.map((item) => '* $item'));
    }
    if (added.isEmpty && fixed.isEmpty && changed.isEmpty) {
      lines.addAll(manualBullets);
    }
    lines.add('');
  }

  File('CHANGELOG.md').writeAsStringSync(lines.join('\n'));
  stdout.writeln('CHANGELOG.md generated successfully!');
}
