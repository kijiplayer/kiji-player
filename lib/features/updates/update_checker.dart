import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/json_file.dart';
import '../settings/data/settings_store.dart';

/// Versión de esta copia de Kiji. Tiene que coincidir con `version:` de
/// `pubspec.yaml` (lo controla un test).
const kijiVersion = '1.0.0';

/// Repositorio oficial. Solo se abre su página; Kiji nunca baja ni instala nada.
const kijiRepo = 'kijiplayer/kiji-player';
const kijiReleasesPage = 'https://github.com/$kijiRepo/releases';

/// Una versión publicada en GitHub.
@immutable
class Release {
  const Release({required this.version, required this.name, required this.notes, required this.url});

  /// Sin la "v" del principio ("1.2.0").
  final String version;
  final String name;
  final String notes;

  /// Página oficial de esa versión (siempre dentro del repositorio de Kiji).
  final String url;

  static Release? fromJson(Object? json) {
    if (json is! Map) return null;
    final tag = '${json['tag_name'] ?? ''}'.trim();
    if (tag.isEmpty || json['draft'] == true || json['prerelease'] == true) return null;
    final url = '${json['html_url'] ?? ''}';
    return Release(
      version: tag.replaceFirst(RegExp('^[vV]'), ''),
      name: '${json['name'] ?? tag}'.trim().isEmpty ? tag : '${json['name']}',
      notes: '${json['body'] ?? ''}'.trim(),
      // Solo páginas del repositorio oficial: otra dirección no se abre nunca.
      url: url.startsWith('https://github.com/$kijiRepo/') ? url : kijiReleasesPage,
    );
  }
}

/// Compara versiones "1.2.10" > "1.2.9". Lo que no sea número cuenta como 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [for (final x in v.split('+').first.split('.')) int.tryParse(x.replaceAll(RegExp(r'\D'), '')) ?? 0];
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Estado de "Actualizaciones" (Tarea W1).
@immutable
class UpdateState {
  const UpdateState({this.lastCheck, this.latest, this.checking = false, this.message});

  final DateTime? lastCheck;

  /// La última versión publicada, si es más nueva que esta.
  final Release? latest;
  final bool checking;

  /// Resultado de la última consulta, en palabras simples.
  final String? message;

  bool get hasUpdate => latest != null;
}

/// Una vez por día (si está prendido) le pregunta a GitHub cuál es la última
/// versión. GitHub ve esa consulta como cualquier visita a una página; no se
/// manda nada más. Nunca descarga ni instala nada: solo muestra las novedades
/// y un botón a la página oficial.
class UpdateNotifier extends Notifier<UpdateState> {
  UpdateNotifier({Dio? dio, Future<String> Function()? directory, DateTime Function()? now})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'KijiPlayer/$kijiVersion'},
            )),
        _directoryPath = directory,
        _now = now ?? DateTime.now;

  final Dio _dio;
  final Future<String> Function()? _directoryPath;
  final DateTime Function() _now;
  JsonFile? _file;

  static const interval = Duration(days: 1);

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
        p.join(await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(), 'updates.json'),
        logTag: 'ACTUALIZACIONES',
      );

  @override
  UpdateState build() => const UpdateState();

  /// Al abrir Kiji: consulta solo si está prendido y pasó un día.
  Future<void> checkIfDue() async {
    // Primero se leen los ajustes: si el usuario lo apagó, no se consulta nunca.
    final settings = await ref.read(settingsProvider.notifier).loaded;
    if (!settings.checkUpdates) return;
    DateTime? last;
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map) last = DateTime.tryParse('${json['lastCheck']}');
    } catch (error) {
      debugPrint('=== ACTUALIZACIONES: no se pudo leer la última consulta: $error ===');
    }
    state = UpdateState(lastCheck: last, latest: state.latest);
    if (last != null && _now().difference(last) < interval) return;
    await checkNow();
  }

  /// "Buscar ahora".
  Future<void> checkNow() async {
    if (state.checking) return;
    state = UpdateState(lastCheck: state.lastCheck, latest: state.latest, checking: true);
    try {
      final response = await _dio.get<Object>(
        'https://api.github.com/repos/$kijiRepo/releases/latest',
        options: Options(validateStatus: (s) => s == 200 || s == 404),
      );
      final now = _now();
      unawaited((await _jsonFile()).write({'lastCheck': now.toIso8601String()}));
      if (response.statusCode == 404) {
        state = UpdateState(lastCheck: now, message: 'Todavía no hay versiones publicadas.');
        return;
      }
      final release = Release.fromJson(response.data);
      final newer = release != null && compareVersions(release.version, kijiVersion) > 0;
      state = UpdateState(
        lastCheck: now,
        latest: newer ? release : null,
        message: newer ? 'Hay una versión nueva: ${release.version}.' : 'Tenés la última versión ($kijiVersion).',
      );
      debugPrint('=== ACTUALIZACIONES: última ${release?.version ?? '?'}, esta $kijiVersion ===');
    } catch (error) {
      debugPrint('=== ACTUALIZACIONES: no se pudo consultar (${error.runtimeType}) ===');
      state = UpdateState(lastCheck: state.lastCheck, latest: state.latest, message: 'No se pudo consultar. Revisá tu conexión.');
    }
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
