import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

/// YouTube de mentira: 401 si el pedido trae la sesión de la cuenta; si no, una respuesta sin audio.
class _FakeYouTube implements HttpClientAdapter {
  final requests = <bool>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final withSession = options.headers.keys.any((k) => k.toLowerCase() == 'authorization');
    requests.add(withSession);
    if (withSession) return ResponseBody.fromString('{"error":"unauthenticated"}', 401);
    return ResponseBody.fromString(
      jsonEncode({'playabilityStatus': {'status': 'OK'}}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(() {
    YtSessionHolder.current = null;
    YtSessionHolder.rejected = false;
  });

  test('si YouTube rechaza la sesión de la cuenta (401), se reintenta sin ella y no se vuelve a mandar', () async {
    YtSessionHolder.current = const YtSession(cookie: 'SAPISID=inventada; OTRA=1');
    final youtube = _FakeYouTube();
    final client = YtMusicClient(playerDio: Dio()..httpClientAdapter = youtube);
    // Una forma que admite la cuenta pero no necesita el solver (para probar solo el pedido).
    const web = YtPlayerClient(
      label: 'WEB_PRUEBA',
      name: 'WEB_REMIX',
      id: '67',
      version: '1.0',
      userAgent: 'prueba',
      loginSupported: true,
    );

    await client.tryClient('videoInventado', web, visitorData: 'visitante');
    expect(youtube.requests, [true, false], reason: 'primero con la sesión (401) y enseguida sin ella');
    expect(YtSessionHolder.rejected, isTrue);

    await client.tryClient('otroVideo', web, visitorData: 'visitante');
    expect(youtube.requests.last, isFalse, reason: 'la sesión rechazada ya no se manda');
  });
}
