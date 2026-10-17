import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _safari = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';
void main() {
  test('hls', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    final body = (await dio.get<String>('https://music.youtube.com/sw.js_data', options: Options(responseType: ResponseType.plain, headers: {'User-Agent': _safari}))).data!;
    String? visitor;
    void walk(dynamic n) { if (visitor != null) return; if (n is String && RegExp(r'^Cg[ts]').hasMatch(n) && n.length > 20) visitor = n; if (n is List) n.forEach(walk); if (n is Map) n.values.forEach(walk); }
    walk(jsonDecode(body.substring(body.indexOf('['))));
    for (final c in [
      ['IOS', '5', '21.03.1', 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)', null, '18.2.22C152', null, null],
      ['IOS', '5', '21.03.3', 'com.google.ios.youtube/21.03.3 (iPad7,6; U; CPU iPadOS 17_7_10 like Mac OS X; en-US)', 'iPadOS', '17.7.10.21H450', 'Apple', 'iPad7,6'],
      ['VISIONOS', '101', '0.1', _safari, 'visionOS', '1.3.21O771', 'Apple', 'RealityDevice14,1'],
    ]) {
      for (final host in ['music.youtube.com', 'www.youtube.com']) {
        for (final id in ['BSTsnWoslP4', 'kJQP7kiw5Fk']) {
          final r = await dio.post<Map<String, dynamic>>('https://$host/youtubei/v1/player', options: Options(headers: {'Content-Type': 'application/json', 'User-Agent': c[3], 'X-YouTube-Client-Name': c[1], 'X-YouTube-Client-Version': c[2], 'X-Goog-Visitor-Id': visitor}),
            data: {'context': {'client': {'clientName': c[0], 'clientVersion': c[2], 'osName': ?c[4], 'osVersion': ?c[5], 'deviceMake': ?c[6], 'deviceModel': ?c[7], 'hl': 'en', 'gl': 'US', 'visitorData': visitor}}, 'videoId': id, 'contentCheckOk': true, 'racyCheckOk': true});
          final hls = r.data?['streamingData']?['hlsManifestUrl'] as String?;
          var info = 'hls=${hls != null}';
          if (hls != null) {
            final master = (await dio.get<String>(hls, options: Options(responseType: ResponseType.plain, headers: {'User-Agent': c[3]}))).data ?? '';
            final audio = master.split('\n').where((l) => l.contains('TYPE=AUDIO')).toList();
            info += ' master=${master.length} audioMedia=${audio.length}';
            final uri = audio.isEmpty ? null : RegExp(r'URI="([^"]+)"').firstMatch(audio.first)?.group(1);
            if (uri != null) {
              final pl = (await dio.get<String>(uri, options: Options(responseType: ResponseType.plain, headers: {'User-Agent': c[3]}))).data ?? '';
              final segs = pl.split('\n').where((l) => l.startsWith('http')).toList();
              info += ' segs=${segs.length}';
              if (segs.isNotEmpty) {
                Future<int?> st(String u) async => (await dio.get<List<int>>(u, options: Options(responseType: ResponseType.bytes, headers: {'User-Agent': c[3]}))).statusCode;
                info += ' primero=${await st(segs.first)} ultimo=${await st(segs.last)}';
              }
              info += ' ${audio.first.substring(0, audio.first.length.clamp(0, 140))}';
            }
          }
          // ignore: avoid_print
          print('HLS ${c[0]} ${c[2]} $host $id: ${r.data?['playabilityStatus']?['status']} $info');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
