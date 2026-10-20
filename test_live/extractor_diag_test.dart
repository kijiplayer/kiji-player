// Diagnóstico del extractor contra YouTube real. No corre con
// `flutter test` normal (está fuera de test/): se corre a mano con
//   flutter test test_live/extractor_diag_test.dart
// Prueba cada forma por separado con 20 canciones y escribe una tabla con el
// resultado y el error exacto de cada una.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

const _queries = [
  'daft punk get lucky', 'bad bunny tití me preguntó', 'soda stereo de música ligera',
  'the weeknd blinding lights', 'shakira hips dont lie', 'queen bohemian rhapsody',
  'karol g provenza', 'coldplay yellow', 'rosalía despechá', 'billie eilish bad guy',
  'cerati crimen', 'dua lipa levitating', 'eminem lose yourself', 'taylor swift anti hero',
  'peso pluma ella baila sola', 'radiohead creep', 'c418 sweden', 'lil peep star shopping',
  'arctic monkeys do i wanna know', 'mana rayando el sol',
];

const _safariUa = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/18.0 Safari/605.1.15';

/// Formas a medir: los clientes de Kiji hoy y los de respaldo de Echo.
final _clients = <Map<String, Object?>>[
  {'label': 'VISIONOS', 'name': 'VISIONOS', 'id': '101', 'version': '0.1', 'ua': _safariUa,
    'osName': 'visionOS', 'osVersion': '1.3.21O771', 'deviceMake': 'Apple', 'deviceModel': 'RealityDevice14,1'},
  {'label': 'ANDROID_VR 1.65.10', 'name': 'ANDROID_VR', 'id': '28', 'version': '1.65.10',
    'ua': 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    'osName': 'Android', 'osVersion': '12L', 'deviceMake': 'Oculus', 'deviceModel': 'Quest 3', 'androidSdkVersion': 32},
  {'label': 'TVHTML5', 'name': 'TVHTML5', 'id': '7', 'version': '7.20260213.00.00',
    'ua': 'Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 (KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15'},
  {'label': 'ANDROID_VR 1.43.32', 'name': 'ANDROID_VR', 'id': '28', 'version': '1.43.32',
    'ua': 'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    'osName': 'Android', 'osVersion': '12', 'deviceMake': 'Oculus', 'deviceModel': 'Quest 3', 'androidSdkVersion': 32},
  {'label': 'IPADOS', 'name': 'IOS', 'id': '5', 'version': '21.03.3',
    'ua': 'com.google.ios.youtube/21.03.3 (iPad7,6; U; CPU iPadOS 17_7_10 like Mac OS X; en-US)',
    'osName': 'iPadOS', 'osVersion': '17.7.10.21H450', 'deviceMake': 'Apple', 'deviceModel': 'iPad7,6'},
  {'label': 'IOS', 'name': 'IOS', 'id': '5', 'version': '21.03.1',
    'ua': 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)', 'osVersion': '18.2.22C152'},
  {'label': 'TVHTML5 www (yt-dlp)', 'name': 'TVHTML5', 'id': '7', 'version': '7.20250923.13.00',
    'ua': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version', 'sts': true, 'host': 'www.youtube.com'},
  {'label': 'TVHTML5 www (Echo)', 'name': 'TVHTML5', 'id': '7', 'version': '7.20260213.00.00',
    'ua': 'Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 (KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15', 'sts': true, 'host': 'www.youtube.com'},
  {'label': 'TVHTML5_SIMPLY www', 'name': 'TVHTML5_SIMPLY', 'id': '75', 'version': '1.0',
    'ua': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version', 'sts': true, 'host': 'www.youtube.com'},
  {'label': 'WEB_EMBEDDED www', 'name': 'WEB_EMBEDDED_PLAYER', 'id': '56', 'version': '1.20250923.21.00',
    'ua': _safariUa, 'sts': true, 'host': 'www.youtube.com'},
  {'label': 'MWEB www', 'name': 'MWEB', 'id': '2', 'version': '2.20250925.01.00',
    'ua': 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)', 'sts': true, 'host': 'www.youtube.com'},
  {'label': 'ANDROID_VR www', 'name': 'ANDROID_VR', 'id': '28', 'version': '1.65.10',
    'ua': 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    'osName': 'Android', 'osVersion': '12L', 'deviceMake': 'Oculus', 'deviceModel': 'Quest 3', 'androidSdkVersion': 32, 'host': 'www.youtube.com'},
  {'label': 'WEB_REMIX', 'name': 'WEB_REMIX', 'id': '67', 'version': '1.20260213.01.00',
    'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0', 'sts': true},
];

Future<String?> _visitorData(Dio dio) async {
  final r = await dio.get<String>('https://music.youtube.com/sw.js_data',
      options: Options(responseType: ResponseType.plain, headers: {'User-Agent': _safariUa}));
  final body = r.data ?? '';
  final decoded = jsonDecode(body.substring(body.indexOf('[')));
  String? found;
  void walk(dynamic n) {
    if (found != null) return;
    if (n is String && RegExp(r'^Cg[ts]').hasMatch(n) && n.length > 20) found = n;
    if (n is List) n.forEach(walk);
    if (n is Map) n.values.forEach(walk);
  }

  walk(decoded);
  return found;
}

Future<int?> _sts(Dio dio) async {
  final html = (await dio.get<String>('https://www.youtube.com/iframe_api',
          options: Options(responseType: ResponseType.plain)))
      .data!;
  final hash = RegExp(r'player\\?/([0-9a-f]{8})\\?/').firstMatch(html)?.group(1);
  if (hash == null) return null;
  final js = (await dio.get<String>('https://www.youtube.com/s/player/$hash/player_ias.vflset/en_US/base.js',
          options: Options(responseType: ResponseType.plain)))
      .data!;
  final m = RegExp(r'signatureTimestamp[=:](\d+)').firstMatch(js) ?? RegExp(r'sts:(\d+)').firstMatch(js);
  return m == null ? null : int.parse(m.group(1)!);
}

Future<String> _probe(Dio dio, String url, String ua, int? length) async {
  Future<int?> range(int from, int to) async {
    try {
      final r = await dio.get<List<int>>(url,
          options: Options(
              responseType: ResponseType.bytes,
              headers: {'User-Agent': ua, 'Range': 'bytes=$from-$to'},
              validateStatus: (_) => true));
      return r.statusCode;
    } catch (e) {
      return -1;
    }
  }

  final first = await range(0, 1023);
  if (length == null || length < 1500000) return 'inicio:$first';
  final far = await range(length - 2048, length - 1);
  return 'inicio:$first final:$far';
}

void main() {
  test('diagnóstico de cada forma con 20 canciones', () async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30)));
    final client = YtMusicClient();
    final ids = <String, String>{};
    for (final q in _queries) {
      final results = await client.search(q, songsOnly: true);
      if (results.isNotEmpty) ids[results.first.videoId] = '${results.first.title} — ${results.first.artist}';
    }
    final visitor = await _visitorData(dio);
    final sts = await _sts(dio);
    final out = StringBuffer('visitorData: ${visitor != null}, sts: $sts, canciones: ${ids.length}\n');

    for (final c in _clients) {
      var full = 0;
      final errors = <String, int>{};
      for (final entry in ids.entries) {
        String verdict;
        try {
          final r = await dio.post<Map<String, dynamic>>(
            'https://${c['host'] ?? 'music.youtube.com'}/youtubei/v1/player',
            queryParameters: {'prettyPrint': 'false'},
            options: Options(validateStatus: (_) => true, headers: {
              'Content-Type': 'application/json',
              'X-YouTube-Client-Name': c['id'],
              'X-YouTube-Client-Version': c['version'],
              'X-Origin': 'https://${c['host'] ?? 'music.youtube.com'}',
              'X-Goog-Visitor-Id': ?visitor,
              'User-Agent': c['ua'],
            }),
            data: {
              'context': {
                'client': {
                  'clientName': c['name'], 'clientVersion': c['version'],
                  for (final k in ['osName', 'osVersion', 'deviceMake', 'deviceModel', 'androidSdkVersion'])
                    if (c[k] != null) k: c[k],
                  'hl': 'es', 'gl': 'US', 'visitorData': ?visitor,
                },
              },
              'videoId': entry.key,
              'contentCheckOk': true, 'racyCheckOk': true,
              if (c['sts'] == true && sts != null)
                'playbackContext': {'contentPlaybackContext': {'signatureTimestamp': sts}},
            },
          );
          final data = r.data;
          if (r.statusCode != 200 || data == null) {
            verdict = 'HTTP ${r.statusCode}: ${jsonEncode(r.data).substring(0, 120)}';
          } else {
            final ps = data['playabilityStatus'] as Map?;
            final formats = ((data['streamingData']?['adaptiveFormats'] as List?) ?? const [])
                .whereType<Map>()
                .where((f) => '${f['mimeType']}'.startsWith('audio/'))
                .toList()
              ..sort((a, b) => ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));
            if (formats.isEmpty) {
              verdict = '${ps?['status']}: ${ps?['reason']}';
            } else if (formats.first['url'] == null) {
              verdict = 'cifrada (signatureCipher), necesita descifrado';
            } else {
              final length = int.tryParse('${formats.first['contentLength']}');
              final probe = await _probe(dio, formats.first['url'] as String, c['ua'] as String, length);
              verdict = probe.contains('final:206') || probe == 'inicio:206'
                  ? 'OK'
                  : 'URL directa pero el audio no baja ($probe)';
            }
          }
        } catch (e) {
          verdict = 'excepción: ${'$e'.split('\n').first}';
        }
        if (verdict == 'OK') {
          full++;
        } else {
          errors[verdict] = (errors[verdict] ?? 0) + 1;
        }
      }
      out.writeln('${c['label']}: $full/${ids.length} OK');
      for (final e in errors.entries) {
        out.writeln('    ${e.value}× $e');
      }
    }
    // ignore: avoid_print
    print(out);
    File(Platform.environment['KIJI_DIAG_OUT'] ?? 'build/extractor_diag.txt').writeAsStringSync('$out');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
