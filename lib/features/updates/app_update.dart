import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../providers/downloads_provider.dart';
import '../dev_tools/dev_build.dart';
import '../settings/data/settings_store.dart';
import 'data/android_update_installer.dart';
import 'data/windows_update_installer.dart';
import 'domain/update_assets.dart';
import 'domain/update_installer.dart';
import 'update_checker.dart';

/// De dónde se bajan las versiones. Kiji solo baja de las releases del repositorio oficial; la
/// fuente de prueba (127.0.0.1) existe solo en Kiji Dev, para probar todo el camino sin publicar.
@immutable
class UpdateSource {
  const UpdateSource({required this.downloadPrefix, this.test = false});

  /// Toda descarga tiene que empezar con esto (otra dirección no se baja nunca).
  final String downloadPrefix;
  final bool test;

  static const official = UpdateSource(downloadPrefix: 'https://github.com/$kijiRepo/releases/download/');

  /// Una "release" servida desde la PC (`adb reverse`), solo en Kiji Dev.
  static const localTest = UpdateSource(downloadPrefix: 'http://127.0.0.1:8787/', test: true);

  bool allows(String url) => url.startsWith(downloadPrefix) && !url.contains('..');
}

enum AppUpdatePhase {
  idle,

  /// "Solo con WiFi" o el ahorro de datos, sin WiFi: se pregunta antes de usar datos móviles.
  askMobileData,
  downloading,
  verifying,

  /// Android: falta el permiso de instalar apps (se explica antes de abrir el ajuste).
  needsPermission,

  /// Windows: verificado; se espera que la persona confirme (Kiji se va a cerrar).
  readyToInstall,
  installing,
  failed,
}

/// Por qué no se pudo actualizar (cada una con su mensaje y siempre el botón a la página).
enum AppUpdateFailure { noAsset, download, noChecksum, checksum, signer, install }

@immutable
class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.version,
    this.asset,
    this.received = 0,
    this.total = 0,
    this.failure,
  });

  final AppUpdatePhase phase;

  /// La versión que se está bajando o instalando.
  final String? version;
  final ReleaseAsset? asset;
  final int received;
  final int total;
  final AppUpdateFailure? failure;

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
  bool get busy => phase == AppUpdatePhase.downloading || phase == AppUpdatePhase.verifying;

  AppUpdateState copyWith({AppUpdatePhase? phase, int? received, int? total, AppUpdateFailure? failure}) =>
      AppUpdateState(
        phase: phase ?? this.phase,
        version: version,
        asset: asset,
        received: received ?? this.received,
        total: total ?? this.total,
        failure: failure,
      );
}

/// "Actualizar" desde Kiji: baja el archivo de la versión nueva (solo cuando la persona toca el
/// botón), lo compara con la suma SHA-256 publicada y, en Android, con el certificado de la app
/// instalada; si algo no coincide, lo borra y no instala. No manda nada de la persona: las
/// descargas son las mismas que se harían desde la página.
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  AppUpdateNotifier({this._installer, this._dio, this._directory, this._mustAskForMobileData});

  UpdateInstaller? _installer;
  Dio? _dio;
  final Future<Directory> Function()? _directory;
  final Future<bool> Function()? _mustAskForMobileData;
  CancelToken? _cancel;
  File? _file;
  Release? _release;
  UpdateSource _source = UpdateSource.official;

  @override
  AppUpdateState build() {
    ref.onDispose(() => _cancel?.cancel());
    return const AppUpdateState();
  }

  /// El instalador de esta plataforma; null donde Kiji no se actualiza sola (Linux, macOS, iOS).
  UpdateInstaller? get installer => _installer ??= Platform.isAndroid
      ? AndroidUpdateInstaller()
      : Platform.isWindows
      ? WindowsUpdateInstaller()
      : null;

  /// ¿Se ofrece "Actualizar"? Kiji Dev nunca se actualiza a la versión pública: solo con la fuente
  /// de prueba.
  bool available(UpdateSource source) => installer != null && (source.test || !isDevBuild);

  Dio get _http => _dio ??= Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'User-Agent': 'KijiPlayer'}, // l10n-ignore
    ),
  );

  /// El archivo que se bajaría para [release] (para mostrar el tamaño), o null.
  Future<ReleaseAsset?> assetFor(Release release, UpdateSource source) async {
    final installer = this.installer;
    if (installer == null || !available(source)) return null;
    try {
      final asset = await installer.pickAsset(release);
      return asset != null && source.allows(asset.url) ? asset : null;
    } catch (error) {
      debugPrint('=== ACTUALIZAR: no se pudo elegir el archivo (${error.runtimeType}) ===');
      return null;
    }
  }

  /// Botón "Actualizar". Con "solo con WiFi" o el ahorro de datos y sin WiFi, primero pregunta.
  Future<void> start(Release release, {UpdateSource source = UpdateSource.official, bool mobileDataOk = false}) async {
    if (state.busy || state.phase == AppUpdatePhase.installing) return;
    _release = release;
    _source = source;
    final asset = await assetFor(release, source);
    if (asset == null) {
      state = AppUpdateState(phase: AppUpdatePhase.failed, version: release.version, failure: AppUpdateFailure.noAsset);
      return;
    }
    if (!mobileDataOk && await _shouldAskForMobileData()) {
      state = AppUpdateState(phase: AppUpdatePhase.askMobileData, version: release.version, asset: asset, total: asset.size);
      return;
    }
    await _download(release, asset);
  }

  Future<bool> _shouldAskForMobileData() async {
    if (_mustAskForMobileData case final ask?) return ask();
    final careful = ref.read(downloadsProvider).settings.wifiOnly || ref.read(settingsProvider).dataSaver;
    if (!careful) return false;
    return !await ref.read(downloadsProvider.notifier).onWifiOrEthernet();
  }

  Future<Directory> _updatesDirectory() async {
    final base = await (_directory ?? getTemporaryDirectory)();
    return Directory(p.join(base.path, 'updates'));
  }

  Future<void> _download(Release release, ReleaseAsset asset) async {
    state = AppUpdateState(phase: AppUpdatePhase.downloading, version: release.version, asset: asset, total: asset.size);
    final cancel = _cancel = CancelToken();
    final dir = await _updatesDirectory();
    try {
      // Una sola descarga a la vez: lo que haya quedado de antes se borra.
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final sums = await _sums(release, cancel);
      final file = _file = File(p.join(dir.path, asset.name));
      await _http.download(
        asset.url,
        file.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (cancel.isCancelled) return;
          final size = total > 0 ? total : asset.size;
          // Cada 0,5 % (y al final): llegan miles de pedacitos y redibujar por cada uno traba.
          if (received < size && received - state.received < size / 200) return;
          state = state.copyWith(received: received, total: size);
        },
      );
      state = state.copyWith(phase: AppUpdatePhase.verifying);
      final expected = expectedSha256(asset, sums);
      if (expected == null) return await _reject(AppUpdateFailure.noChecksum);
      if (!await verifySha256(file, expected)) return await _reject(AppUpdateFailure.checksum);
      if (await installer!.sameSigner(file) == false) return await _reject(AppUpdateFailure.signer);
      debugPrint('=== ACTUALIZAR: ${asset.name} verificado (SHA-256 y firma) ===');
      if (installer!.confirmBeforeInstall) {
        state = state.copyWith(phase: AppUpdatePhase.readyToInstall);
        return;
      }
      await install();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        debugPrint('=== ACTUALIZAR: descarga cancelada ===');
        await _deleteFile();
        state = const AppUpdateState();
        return;
      }
      debugPrint('=== ACTUALIZAR: no se pudo bajar (${error.type.name} ${error.response?.statusCode ?? ''}) ===');
      await _deleteFile();
      state = state.copyWith(phase: AppUpdatePhase.failed, failure: AppUpdateFailure.download);
    } catch (error) {
      debugPrint('=== ACTUALIZAR: falló la descarga (${error.runtimeType}) ===');
      await _deleteFile();
      state = state.copyWith(phase: AppUpdatePhase.failed, failure: AppUpdateFailure.download);
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Las sumas de SHA256SUMS.txt, si la versión lo trae (si no, queda la de GitHub).
  Future<Map<String, String>> _sums(Release release, CancelToken cancel) async {
    final file = release.assets.where((a) => a.name == sha256SumsName).firstOrNull;
    if (file == null || !_source.allows(file.url)) return const {};
    final response = await _http.get<String>(
      file.url,
      cancelToken: cancel,
      options: Options(responseType: ResponseType.plain),
    );
    return parseSha256Sums(response.data ?? '');
  }

  /// Algo no coincide: el archivo se borra y no se instala.
  Future<void> _reject(AppUpdateFailure failure) async {
    debugPrint('=== ACTUALIZAR: el archivo no es el publicado (${failure.name}); se borra y no se instala ===');
    await _deleteFile();
    state = state.copyWith(phase: AppUpdatePhase.failed, failure: failure);
  }

  Future<void> _deleteFile() async {
    final file = _file;
    _file = null;
    try {
      if (file != null && file.existsSync()) await file.delete();
    } catch (error) {
      debugPrint('=== ACTUALIZAR: no se pudo borrar el archivo (${error.runtimeType}) ===');
    }
  }

  /// "Cancelar" mientras baja.
  void cancel() => _cancel?.cancel();

  /// Cerrar el aviso de error o de datos móviles.
  void reset() {
    if (state.busy) return;
    state = const AppUpdateState();
  }

  /// "Usar datos móviles" en la pregunta.
  Future<void> useMobileData() async {
    final release = _release;
    if (release == null) return;
    await start(release, source: _source, mobileDataOk: true);
  }

  /// Instala el archivo verificado. En Android, si falta el permiso, primero se explica.
  Future<void> install() async {
    final file = _file;
    final installer = this.installer;
    if (file == null || installer == null || !file.existsSync()) {
      state = state.copyWith(phase: AppUpdatePhase.failed, failure: AppUpdateFailure.download);
      return;
    }
    try {
      if (!await installer.canInstall()) {
        state = state.copyWith(phase: AppUpdatePhase.needsPermission);
        return;
      }
      state = state.copyWith(phase: AppUpdatePhase.installing);
      await installer.install(file);
    } catch (error) {
      debugPrint('=== ACTUALIZAR: no se pudo abrir el instalador (${error.runtimeType}) ===');
      state = state.copyWith(phase: AppUpdatePhase.failed, failure: AppUpdateFailure.install);
    }
  }

  /// "Ir a los ajustes" (después de leer por qué).
  Future<void> openPermission() async {
    try {
      await installer?.openInstallPermission();
    } catch (error) {
      debugPrint('=== ACTUALIZAR: no se pudo abrir el ajuste (${error.runtimeType}) ===');
      state = state.copyWith(phase: AppUpdatePhase.failed, failure: AppUpdateFailure.install);
    }
  }

  /// De vuelta en Kiji después del ajuste: si ya dio el permiso, se instala.
  Future<void> resumeAfterPermission() async {
    if (state.phase != AppUpdatePhase.needsPermission) return;
    if (await installer?.canInstall() ?? false) await install();
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);
