// Tarea Z4 (traducción). Solo textos inventados: nunca letras reales.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/translation/data/bergamot_engine.dart';
import 'package:kiji_player/features/translation/data/bergamot_models.dart';
import 'package:kiji_player/features/translation/data/gemini_client.dart';
import 'package:kiji_player/features/translation/data/translation_service.dart';
import 'package:kiji_player/features/translation/domain/languages.dart';
import 'package:kiji_player/features/translation/presentation/lyrics_settings_screens.dart';
import 'package:kiji_player/utils/secret_store.dart';

class _MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  bool get isSupported => true;
  @override
  Future<bool> write(String name, String value) async {
    values[name] = value;
    return true;
  }

  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> delete(String name) async => values.remove(name);
}

class _FakeGemini extends GeminiClient {
  int calls = 0;
  List<String>? lastLines;
  GeminiException? fail;

  @override
  Future<List<String>> translate(String key, String model, List<String> lines, String target) async {
    calls++;
    lastLines = lines;
    if (fail != null) throw fail!;
    return [for (final l in lines) '[$target] $l'];
  }
}

class _FakeEngine extends BergamotEngine {
  _FakeEngine(super.models);
  int calls = 0;

  @override
  Future<List<String>> translate(List<LanguagePair> route, List<String> lines) async {
    calls++;
    return [for (final l in lines) l.toUpperCase()];
  }
}

Map<String, Object?> _record(String from, String to, String version, String type, {String? filter}) => {
      'fromLang': from,
      'toLang': to,
      'version': version,
      'fileType': type,
      'name': '$type.$from$to.bin',
      'filter_expression': filter,
      'attachment': {'location': 'main/$from$to$version$type', 'size': 100, 'hash': 'h$type'},
    };

void main() {
  group('Detección de idioma', () {
    test('Inglés, español y portugués con frases inventadas', () {
      expect(detectLanguage(['The sun is warm today', 'We walk along the river']), 'en');
      expect(detectLanguage(['El sol está tibio hoy', 'Caminamos por el río con los amigos']), 'es');
      expect(detectLanguage(['O sol está quente hoje', 'Nós caminhamos com os amigos não']), 'pt');
    });

    test('Por escritura (japonés, coreano, ruso)', () {
      expect(detectLanguage(['きょうは はれ です']), 'ja');
      expect(detectLanguage(['오늘은 맑아요']), 'ko');
      expect(detectLanguage(['Сегодня тёплый день']), anyOf('ru', 'uk'));
    });

    test('Sin texto no adivina', () {
      expect(detectLanguage(['', '   ']), isNull);
    });

    test('Nombres de idioma', () {
      expect(translationLanguages.keys.first, 'es');
      expect(languageName('en'), 'Inglés');
    });
  });

  group('Catálogo de Mozilla', () {
    test('Filtro por plataforma', () {
      expect(recordFitsPlatform(null, android: true), isTrue);
      expect(recordFitsPlatform("env.appinfo.OS == 'Android'", android: true), isTrue);
      expect(recordFitsPlatform("env.appinfo.OS == 'Android'", android: false), isFalse);
      expect(recordFitsPlatform("env.appinfo.OS != 'Android'", android: false), isTrue);
      expect(recordFitsPlatform("env.channel == 'nightly'", android: false), isFalse);
    });

    test('Elige la versión completa más nueva', () {
      final records = [
        _record('en', 'es', '1.0', 'model'),
        _record('en', 'es', '1.0', 'vocab'),
        _record('en', 'es', '1.0', 'lex'),
        _record('en', 'es', '2.0', 'model'), // incompleta: le falta el vocabulario
        _record('en', 'es', '1.1', 'model'),
        _record('en', 'es', '1.1', 'srcvocab'),
        _record('en', 'es', '1.1', 'trgvocab'),
      ];
      final files = pickModelFiles(records, 'en', 'es', android: false)!;
      expect({for (final f in files) f.fileType}, {'model', 'srcvocab', 'trgvocab'});
      expect(files.first.url, startsWith('https://firefox-settings-attachments.cdn.mozilla.net/main/'));
      expect(pickModelFiles(records, 'es', 'en', android: false), isNull);
    });
  });

  group('Gemini (respuestas)', () {
    test('Solo modelos de texto, Flash-Lite primero', () {
      final models = textModels({
        'models': [
          {'name': 'models/gemini-2.5-flash', 'displayName': 'Flash', 'supportedGenerationMethods': ['generateContent']},
          {'name': 'models/gemini-2.5-flash-lite', 'displayName': 'Lite', 'supportedGenerationMethods': ['generateContent']},
          {'name': 'models/gemini-embedding-001', 'supportedGenerationMethods': ['embedContent']},
          {'name': 'models/gemini-2.5-flash-image', 'supportedGenerationMethods': ['generateContent']},
          {'name': 'models/imagen-4', 'supportedGenerationMethods': ['predict']},
          {'name': 'models/gemini-3.1-flash-lite-preview', 'supportedGenerationMethods': ['generateContent']},
          {'name': 'models/gemini-3.5-transcribe', 'supportedGenerationMethods': ['generateContent']},
          {'name': 'models/gemini-3.1-pro-preview-customtools', 'supportedGenerationMethods': ['generateContent']},
        ],
      });
      expect([for (final m in models) m.name], [
        'models/gemini-2.5-flash-lite',
        'models/gemini-3.1-flash-lite-preview',
        'models/gemini-2.5-flash',
      ]);
      expect(models.first.isLite, isTrue);
      expect(textModels(null), isEmpty);
    });

    test('Texto de la respuesta', () {
      expect(
        responseText({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '["Hola"]'},
                ],
              },
            },
          ],
        }),
        '["Hola"]',
      );
      expect(responseText({'candidates': []}), isNull);
    });
  });

  group('Servicio de traducción', () {
    late Directory dir;
    late _MemorySecrets secrets;
    late _FakeGemini gemini;
    late _FakeEngine engine;
    late TranslationService service;
    const lines = ['The sun is warm today', '', 'We walk along the river'];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kiji_tr');
      secrets = _MemorySecrets();
      gemini = _FakeGemini();
      final models = BergamotModels(directory: () async => dir, android: false);
      engine = _FakeEngine(models);
      service = TranslationService(
        models: models,
        engine: engine,
        gemini: gemini,
        secrets: secrets,
        directory: () async => dir,
      );
    });

    tearDown(() => dir.delete(recursive: true));

    test('Gemini sin clave pide la clave y ofrece el teléfono', () async {
      await expectLater(
        service.translateGemini('v1', lines, 'models/x', 'es'),
        throwsA(isA<TranslationException>().having((e) => e.suggestLocal, 'suggestLocal', isTrue)),
      );
    });

    test('Gemini: solo líneas con texto, una por original, y queda en caché', () async {
      await secrets.write(geminiKeySecret, 'clave-inventada');
      final out = await service.translateGemini('v1', lines, 'models/x', 'es');
      expect(gemini.lastLines, ['The sun is warm today', 'We walk along the river']);
      expect(out, ['[es] The sun is warm today', null, '[es] We walk along the river']);
      final again = await service.translateGemini('v1', lines, 'models/x', 'es');
      expect(again, out);
      expect(gemini.calls, 1);
      // Si la letra cambia, la caché no sirve.
      expect(await service.cached('v1', ['Otra línea'], 'gemini', 'es'), isNull);
    });

    test('Error de Gemini se explica y ofrece el teléfono', () async {
      await secrets.write(geminiKeySecret, 'clave-inventada');
      gemini.fail = const GeminiException('Llegaste al límite gratuito de Gemini por hoy. Prueba mañana.');
      await expectLater(
        service.translateGemini('v2', lines, 'models/x', 'es'),
        throwsA(isA<TranslationException>()
            .having((e) => e.suggestLocal, 'suggestLocal', isTrue)
            .having((e) => e.message, 'message', contains('límite'))),
      );
    });

    test('En el teléfono: traduce, guarda y no repite', () async {
      const plan = LocalPlan(source: 'en', route: [(from: 'en', to: 'es')], missingBytes: 0);
      final out = await service.translateLocal('v3', lines, plan, 'es');
      expect(out, ['THE SUN IS WARM TODAY', null, 'WE WALK ALONG THE RIVER']);
      await service.translateLocal('v3', lines, plan, 'es');
      expect(engine.calls, 1);
    });

    test('Misma lengua: no hay nada que traducir', () async {
      await expectLater(
        service.planLocal(['El sol está tibio hoy', 'Caminamos por el río con los amigos'], 'es'),
        throwsA(isA<TranslationException>()),
      );
    });
  });

  group('Ajustes', () {
    test('Traducción y fuentes se guardan', () {
      const s = AppSettings(
        translationTarget: 'pt',
        geminiEnabled: true,
        useGemini: true,
        geminiModel: 'models/gemini-2.5-flash-lite',
        disabledLyricsSources: {LyricsSource.kugou},
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.translationTarget, 'pt');
      expect(r.geminiEnabled, isTrue);
      expect(r.useGemini, isTrue);
      expect(r.geminiModel, 'models/gemini-2.5-flash-lite');
      expect(r.disabledLyricsSources, {LyricsSource.kugou});
    });

    test('Gemini apagado de fábrica', () {
      const s = AppSettings();
      expect(s.geminiEnabled, isFalse);
      expect(s.useGemini, isFalse);
      expect(s.translationTarget, 'es');
    });
  });

  group('Pantallas', () {
    testWidgets('Avisos de Gemini: cuatro puntos y "Entiendo, activar"', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<bool>(MaterialPageRoute(builder: (_) => const GeminiConsentScreen())),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(GeminiConsentScreen.points, hasLength(4));
      expect(find.textContaining('18 años'), findsOneWidget);
      expect(find.textContaining('Suiza'), findsOneWidget);
      await tester.tap(find.text('Entiendo, activar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Fuentes: apagar una la guarda en los ajustes', (tester) async {
      final container = ProviderContainer(overrides: [
        settingsProvider.overrideWith(_MemorySettings.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LyricsSourcesScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LyricsSource.online.first.label));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).disabledLyricsSources, {LyricsSource.online.first});
    });
  });
}

class _MemorySettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();

  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}
