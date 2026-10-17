import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/data/extractor_health.dart';
import 'package:kiji_player/features/yt_music/data/player_script.dart';
import 'package:kiji_player/features/yt_music/data/po_token.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/features/yt_music/presentation/extractor_health_screen.dart';

void main() {
  group('orden de las formas', () {
    final labels = [for (final c in ytPlayerClients) c.label];

    test('primero las que funcionan, después las que fallan', () {
      expect(labels.take(4), ['VISIONOS', 'VISIONOS_HLS', 'TVHTML5_SIMPLY', 'TVHTML5_SIMPLY_MUSIC']);
      expect(labels.skip(4), containsAllInOrder(['ANDROID_VR', 'WEB_REMIX', 'MWEB']));
      expect(labels.toSet().length, labels.length, reason: 'sin repetidas');
    });

    test('las de respaldo de Echo mantienen su orden y no hay clientes con sesión', () {
      const echo = ['VISIONOS', 'ANDROID_VR', 'TVHTML5', 'ANDROID_VR_1.43', 'IPADOS', 'IOS'];
      expect(labels.where(echo.contains), echo);
      expect(labels.any((l) => l.contains('CREATOR')), isFalse, reason: 'WEB_CREATOR exige iniciar sesión');
      expect(ExtractorHealth.clients, labels);
    });

    test('solo las web y de TV mandan PO token; solo las cifradas piden el reproductor', () {
      expect(clientByLabel('VISIONOS')!.usesPoToken, isFalse);
      expect(clientByLabel('TVHTML5_SIMPLY')!.usesPoToken, isTrue);
      expect(clientByLabel('TVHTML5_SIMPLY')!.needsPlayerScript, isTrue);
      expect(clientByLabel('VISIONOS_HLS')!.useHls, isTrue);
      expect(clientByLabel('ANDROID_VR')!.needsPlayerScript, isFalse);
    });
  });

  group('reproductor de YouTube', () {
    test('hash, signatureTimestamp y tabla de Echo con alias', () {
      const iframe = r"var scriptUrl = 'https:\/\/www.youtube.com\/s\/player\/0229cd64\/www-widgetapi.vflset";
      expect(playerHashFrom(iframe), '0229cd64');
      expect(playerHashFrom('nada'), isNull);
      expect(signatureTimestampFrom('a,signatureTimestamp:20739,b'), 20739);
      expect(signatureTimestampFrom('x={sts:20690}'), 20690);
      expect(signatureTimestampFrom('sin nada'), isNull);
      final table = {
        'players': {
          'bd4a2521': {'sts': 20690, 'aliases': ['6413e259']},
        },
      };
      expect(stsFromConfigTable(table, 'bd4a2521'), 20690);
      expect(stsFromConfigTable(table, '6413e259'), 20690);
      expect(stsFromConfigTable(table, 'ffffffff'), isNull);
      expect(stsFromConfigTable(const {}, 'bd4a2521'), isNull);
    });
  });

  group('lista HLS', () {
    const master = '#EXTM3U\n'
        '#EXT-X-MEDIA:URI="https://a/233/index.m3u8",TYPE=AUDIO,GROUP-ID="233",NAME="Default"\n'
        '#EXT-X-MEDIA:URI="https://a/234/index.m3u8",TYPE=AUDIO,GROUP-ID="234",NAME="Default"\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="234"\nhttps://a/video.m3u8\n';

    test('elige el audio de más calidad, o el más liviano con ahorro de datos', () {
      expect(YtMusicClient.pickHlsAudio(master), 'https://a/234/index.m3u8');
      expect(YtMusicClient.pickHlsAudio(master, lowQuality: true), 'https://a/233/index.m3u8');
      expect(YtMusicClient.pickHlsAudio('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8'), isNull);
    });

    test('la duración es la suma de los segmentos', () {
      const playlist = '#EXTM3U\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXTINF:5.0,\nhttps://s/1\n'
          '#EXTINF:5.0,\nhttps://s/2\n#EXTINF:2.5,\nhttps://s/3\n#EXT-X-ENDLIST\n';
      expect(YtMusicClient.hlsDuration(playlist), const Duration(milliseconds: 12500));
    });
  });

  group('PO token', () {
    test('desmezcla el desafío y arma sus campos', () {
      final inner = jsonEncode(['msg', ['codigo-js'], null, 'hash', 'programa', 'nombreGlobal', null, 'blob']);
      // "Mezclar" es restar 97 a cada byte y pasar a base64.
      final scrambled = base64Encode([for (final b in utf8.encode(inner)) (b - 97) & 0xff]);
      expect(descrambleChallenge(scrambled), inner);
      final challenge = parseChallenge(jsonEncode([null, scrambled]));
      expect(challenge['interpreterJavascript'], 'codigo-js');
      expect(challenge['program'], 'programa');
      expect(challenge['globalName'], 'nombreGlobal');
      // También en la forma sin mezclar.
      expect(parseChallenge(jsonEncode([jsonDecode(inner)]))['globalName'], 'nombreGlobal');
    });

    test('base64 de YouTube ida y vuelta', () {
      final bytes = [251, 255, 0, 62, 63];
      final token = poTokenToBase64(bytes);
      expect(token.contains('+') || token.contains('/'), isFalse);
      expect(youtubeBase64Decode(token), bytes);
      expect(youtubeBase64Decode('-_8.'), [251, 255]);
    });
  });

  testWidgets('"Probar todas las formas ahora" muestra cada resultado', (tester) async {
    tester.view.physicalSize = const Size(500, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final health = ExtractorHealth.instance..resetForTest();
    final played = <String>[];

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ExtractorHealthScreen(
          health: health,
          tester: (id, client) async => client.label.startsWith('TVHTML5_SIMPLY')
              ? StreamAttempt(client.label, url: 'https://audio/$id')
              : StreamAttempt(client.label, reason: 'LOGIN_REQUIRED: falso'),
          playChecker: (attempt, client) async {
            played.add(client.label);
            return client.label == 'TVHTML5_SIMPLY_MUSIC' ? 'Resolvió, pero no suena: falso' : null;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Probar todas las formas ahora'));
    await tester.pumpAndSettle();

    // Se escucha una sola vez por forma que resolvió.
    expect(played, ['TVHTML5_SIMPLY', 'TVHTML5_SIMPLY_MUSIC']);
    expect(find.textContaining('3 de 3 canciones bien y suena entera'), findsOneWidget);
    expect(find.textContaining('resolvió pero no suena'), findsOneWidget);
    expect(find.textContaining('falló — LOGIN_REQUIRED: falso'), findsNWidgets(ytPlayerClients.length - 2));
    expect(find.textContaining('En la prueba funcionan 1 de ${ytPlayerClients.length} formas'), findsOneWidget);
  });
}
