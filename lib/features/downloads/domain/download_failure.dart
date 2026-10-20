import 'dart:io';

import 'package:dio/dio.dart';

import '../../extractor/data/stream_resolver.dart';
import '../../extractor/domain/extraction_failure.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Por qué no bajó una canción.
enum DownloadFailureKind {
  /// Problema de la canción (edad, borrada, bloqueada…): reintentar no sirve; otra versión, quizás.
  content,

  /// YouTube no dio el audio con ninguna forma (con internet). Suele arreglarse solo.
  allForms,

  /// Se cortó la conexión. Al reintentar sigue desde donde quedó.
  network,

  /// YouTube cortó la descarga a mitad de camino con las formas que se probaron.
  refused,

  /// No queda espacio en el dispositivo.
  noSpace,
  unknown,
}

/// Una falla de descarga, con el motivo en palabras simples para la lista.
class DownloadFailure {
  const DownloadFailure(this.kind, this.message, {this.problem, this.noAlternative = false});

  final DownloadFailureKind kind;
  final String message;
  final ContentProblem? problem;

  /// Ya se buscó otra versión y no hay (el botón deja de ofrecerse).
  final bool noAlternative;

  /// "Buscar otra versión" tiene sentido: la canción en sí no se puede bajar con este video.
  bool get canSearchAlternative =>
      !noAlternative &&
      (kind == DownloadFailureKind.content ||
          kind == DownloadFailureKind.allForms ||
          kind == DownloadFailureKind.refused);

  /// La misma falla, después de buscar otra versión sin encontrarla: se conserva el motivo.
  DownloadFailure withoutAlternative() => DownloadFailure(
    kind,
    tx.kijiBuscoOtraVersionEnYoutube(
      message.replaceAll(tx.puedesBuscarOtraVersionSufijo, '').replaceAll(tx.oBuscaOtraVersionSufijo, ''),
    ),
    problem: problem,
    noAlternative: true,
  );

  static DownloadFailure get network => DownloadFailure(DownloadFailureKind.network, tx.seCortoLaConexionAlReintentar);
  static DownloadFailure get allFormsFailed => DownloadFailure(DownloadFailureKind.allForms, tx.youtubeNoEntregoElAudioCon);
  static DownloadFailure get refusedMidway => DownloadFailure(DownloadFailureKind.refused, tx.youtubeCortoLaDescargaAMitad);
  static DownloadFailure get noSpace => DownloadFailure(DownloadFailureKind.noSpace, tx.noQuedaEspacioEnElDispositivo);
  static DownloadFailure get unknown => DownloadFailure(DownloadFailureKind.unknown, tx.noSePudoDescargarReintentaEn);

  /// El resultado de buscar el audio, en palabras simples.
  static DownloadFailure fromOutcome(ResolveOutcome outcome) {
    final problem = outcome.problem;
    if (problem != null) return DownloadFailure(DownloadFailureKind.content, contentText(problem), problem: problem);
    if (outcome.offline) return network;
    return allFormsFailed;
  }

  /// Un error durante la descarga, en palabras simples.
  static DownloadFailure fromError(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      // 28 = ENOSPC (Android/Linux), 112 = ERROR_DISK_FULL (Windows).
      if (code == 28 || code == 112 || '${error.osError?.message}'.toLowerCase().contains('space')) return noSpace;
    }
    if (error is DioException || error is SocketException || error is HttpException) return network;
    return unknown;
  }

  /// Texto para una canción que tiene un problema propio.
  static String contentText(ContentProblem problem) => switch (problem) {
    ContentProblem.ageRestricted => tx.tieneRestriccionDeEdadYoutubeNo,
    ContentProblem.unavailable => tx.youtubeMusicYaNoLaOfrece,
    ContentProblem.private => tx.elVideoEsPrivado,
    ContentProblem.removed => tx.elVideoFueBorradoDeYoutube,
    ContentProblem.regionBlocked => tx.noEstaDisponibleEnTuPais,
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'message': message,
    if (problem != null) 'problem': problem!.name,
    if (noAlternative) 'noAlternative': true,
  };

  static DownloadFailure fromJson(Map<String, dynamic> json) => DownloadFailure(
    DownloadFailureKind.values.asNameMap()[json['kind']] ?? DownloadFailureKind.unknown,
    json['message'] as String? ?? unknown.message,
    problem: ContentProblem.values.asNameMap()[json['problem']],
    noAlternative: json['noAlternative'] == true,
  );
}
