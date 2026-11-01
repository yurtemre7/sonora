import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late Directory tempDir;
  var requests = <String>[];
  var apkBytes = List<int>.generate(100000, (i) => i % 251);
  var releaseTag = 'v99.0.0';
  var releaseStatus = 200;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  setUpAll(() async {
    // flutter_test replaces HttpClient with a stub that fails every request.
    HttpOverrides.global = null;
    tempDir = Directory.systemTemp.createTempSync('update_service_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? tempDir.path : null,
        );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      var response = request.response;
      switch (request.uri.path) {
        case '/apk':
          response.contentLength = apkBytes.length;
          response.add(apkBytes);
        case '/apk-redirect':
          response.redirect(url('/apk'));
          return;
        case '/changelog':
          response.write('# Changelog\n\nüñí ✓');
        case '/release':
          response.statusCode = releaseStatus;
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode({
              'tag_name': releaseTag,
              'html_url': 'https://example.test/release',
              'body': 'notes',
              'assets': [
                {
                  'name': 'sonora-arm64-v8a.apk',
                  'browser_download_url': 'https://example.test/arm64.apk',
                },
                {
                  'name': 'sonora-x86_64.apk',
                  'browser_download_url': 'https://example.test/x86_64.apk',
                },
              ],
            }),
          );
        default:
          response.statusCode = 404;
      }
      await response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    requests.clear();
    releaseTag = 'v99.0.0';
    releaseStatus = 200;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('downloadApk', () {
    test('writes the full file and reports progress', () async {
      var calls = <(int, int)>[];
      var path = await UpdateService.downloadApk(
        url('/apk').toString(),
        onProgress: (received, total) => calls.add((received, total)),
      );

      expect(File(path).readAsBytesSync(), apkBytes);
      expect(calls, isNotEmpty);
      expect(calls.last, (apkBytes.length, apkBytes.length));
    });

    test('follows redirects like GitHub release assets', () async {
      var path = await UpdateService.downloadApk(
        url('/apk-redirect').toString(),
        onProgress: (_, _) {},
      );

      expect(File(path).lengthSync(), apkBytes.length);
      expect(requests, ['GET /apk-redirect', 'GET /apk']);
    });

    test('deletes the partial file when the download fails midway', () async {
      await expectLater(
        UpdateService.downloadApk(
          url('/apk').toString(),
          onProgress: (_, _) => throw StateError('stop'),
        ),
        throwsStateError,
      );
      expect(File('${tempDir.path}/sonora_update.apk').existsSync(), isFalse);
    });

    test('throws on non-200 and leaves no file', () async {
      await expectLater(
        UpdateService.downloadApk(
          url('/missing').toString(),
          onProgress: (_, _) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('HTTP error 404'),
          ),
        ),
      );
      expect(File('${tempDir.path}/sonora_update.apk').existsSync(), isFalse);
    });
  });

  group('fetchChangelog', () {
    test('returns UTF-8 body and serves the cache within 12h', () async {
      var first = await UpdateService.fetchChangelog(url: url('/changelog'));
      var second = await UpdateService.fetchChangelog(url: url('/changelog'));

      expect(first, '# Changelog\n\nüñí ✓');
      expect(second, first);
      expect(requests, ['GET /changelog']);
    });

    test('forceRefresh bypasses the cache', () async {
      await UpdateService.fetchChangelog(url: url('/changelog'));
      await UpdateService.fetchChangelog(
        forceRefresh: true,
        url: url('/changelog'),
      );

      expect(requests, ['GET /changelog', 'GET /changelog']);
    });

    test('returns null and caches nothing on non-200', () async {
      expect(await UpdateService.fetchChangelog(url: url('/missing')), isNull);
      expect(
        await SharedPreferencesAsync().getString('cached_changelog_content'),
        isNull,
      );
    });

    test('returns null when the server is unreachable', () async {
      expect(
        await UpdateService.fetchChangelog(
          url: Uri.parse('http://127.0.0.1:1/x'),
        ),
        isNull,
      );
    });
  });

  group('checkForUpdate', () {
    Future<UpdateResult> check() => UpdateService.checkForUpdate(
      apiUrl: url('/release'),
      changelogUrl: url('/changelog'),
    );

    test('reports a newer release with parsed assets', () async {
      var result = await check();
      var update = result.update!;

      expect(update.version, 'v99.0.0');
      expect(update.changelog, 'notes');
      expect(update.apkAssets.keys, ['arm64-v8a', 'x86_64']);
      expect(update.recommendedAbi, 'arm64-v8a');
      expect(update.recommendedUrl, 'https://example.test/arm64.apk');
      expect(requests, contains('GET /changelog'));
    });

    test('reports up to date for an older tag', () async {
      releaseTag = 'v0.0.1';
      var result = await check();

      expect(result.update, isNull);
      expect(result.hasError, isFalse);
      expect(result.isRateLimited, isFalse);
    });

    test('maps 403 and 429 to rate limited', () async {
      for (var status in [403, 429]) {
        releaseStatus = status;
        expect((await check()).isRateLimited, isTrue, reason: '$status');
      }
    });

    test('maps other failures and unreachable hosts to error', () async {
      releaseStatus = 500;
      expect((await check()).hasError, isTrue);

      var unreachable = await UpdateService.checkForUpdate(
        apiUrl: Uri.parse('http://127.0.0.1:1/x'),
      );
      expect(unreachable.hasError, isTrue);
    });
  });
}
