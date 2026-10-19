import 'dart:io';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/account/data/account_store.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/extractor/domain/extraction_failure.dart';
import 'package:kiji_player/features/extractor/domain/resolved_stream.dart';
import 'package:kiji_player/features/reports/data/log_scrubber.dart';
import 'package:kiji_player/utils/secret_store.dart';

/// Almacén de secretos en memoria (en el teléfono es el Keystore; en Windows, DPAPI).
class _MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  bool get isSupported => true;
  @override
  Future<bool> write(String name, String value) async => (values[name] = value) == value;
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> delete(String name) async => values.remove(name);
}

class _FakeEngine extends ExtractionEngine {
  _FakeEngine(this.id, this.answer);
  @override
  final EngineId id;
  final EngineResult Function() answer;
  int calls = 0;
  @override
  bool get isSupported => true;
  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async {
    calls++;
    return answer();
  }
}

// Cookies inventadas (nunca de una cuenta real).
const _session = YtSession(cookie: 'SAPISID=abc123/def; SID=zzz; HSID=yyy', visitorData: 'Cgt2aXNpdG9y', dataSyncId: '1234');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => YtSessionHolder.current = null);

  test('Encabezado SAPISIDHASH como el navegador: segundos_sha1("segundos SAPISID origen")', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1792300000000);
    final headers = _session.authHeaders(now: now);
    final expected = sha1.convert(utf8.encode('1792300000 abc123/def https://music.youtube.com')).toString();
    expect(headers['Authorization'], 'SAPISIDHASH 1792300000_$expected');
    expect(headers['Cookie'], _session.cookie);
    expect(_session.isValid, isTrue);
    expect(const YtSession(cookie: 'PREF=x').isValid, isFalse, reason: 'sin SAPISID no es una sesión');
  });

  test('La sesión nunca aparece en el registro', () {
    expect('$_session', isNot(contains('abc123')));
    expect(scrubPersonalData('Cookie: ${_session.cookie}'), isNot(contains('abc123')));
    final auth = _session.authHeaders()['Authorization']!;
    expect(scrubPersonalData('Authorization: $auth'), isNot(contains(auth.split(' ').last)));
  });

  test('Iniciar sesión la guarda cifrada; cerrar sesión borra todo', () async {
    final secrets = _MemorySecrets();
    final container = ProviderContainer(overrides: [
      accountProvider.overrideWith(() => AccountNotifier(secrets: secrets)),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(accountProvider.notifier);
    await notifier.loaded;
    expect(await notifier.signIn(_session), isTrue);
    expect(secrets.values[ytSessionSecret], contains('SAPISID'));
    expect(YtSessionHolder.signedIn, isTrue);

    await notifier.signOut();
    expect(secrets.values, isEmpty);
    expect(container.read(accountProvider), isNull);
    expect(YtSessionHolder.signedIn, isFalse);
  });

  test('Con sesión, una restricción de edad no corta: se prueban las formas que mandan la cuenta', () async {
    final age = classifyFailure('Sign in to confirm your age');
    final a = _FakeEngine(EngineId.a, () => EngineResult.failed([('AUTO', age)]));
    final b = _FakeEngine(
        EngineId.b,
        () => const EngineResult.ok(
            ResolvedStream(videoId: 'abcdefghijk', url: 'https://g/1', engine: EngineId.b, form: 'WEB_REMIX')));
    final dir = Directory.systemTemp.createTempSync('kiji_c6');
    addTearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows a veces la tiene abierta un instante; es una carpeta temporal.
      }
    });
    final health = PathHealth(directory: () async => dir.path);

    final anonymous = await StreamResolver(engines: [a, b], health: health, signedIn: () => false).resolve('abcdefghijk');
    expect(anonymous.problem, ContentProblem.ageRestricted);
    expect(b.calls, 0);

    final withAccount = await StreamResolver(engines: [a, b], health: health, signedIn: () => true).resolve('abcdefghijk');
    expect(withAccount.stream?.path, 'B/WEB_REMIX');
  });
}
