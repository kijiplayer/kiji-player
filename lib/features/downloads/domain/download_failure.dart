import 'dart:io';

import 'package:dio/dio.dart';

import '../../extractor/data/stream_resolver.dart';
import '../../extractor/domain/extraction_failure.dart';

/// Por qué no bajó una canción (Tarea T4).
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
  const DownloadFailure(this.kind, this.message, {this.problem});

  final DownloadFailureKind kind;
  final String message;
  final ContentProblem? problem;

  /// "Buscar otra versión" tiene sentido: la canción en sí no se puede bajar con este video.
  bool get canSearchAlternative =>
      kind == DownloadFailureKind.content || kind == DownloadFailureKind.allForms || kind == DownloadFailureKind.refused;

  static const network = DownloadFailure(
    DownloadFailureKind.network,
    'Se cortó la conexión. Al reintentar sigue desde donde quedó.',
  );
  static const allFormsFailed = DownloadFailure(
    DownloadFailureKind.allForms,
    'YouTube no entregó el audio con ninguna de las formas que probó Kiji. '
    'Suele arreglarse solo: reintenta en un rato o busca otra versión.',
  );
  static const refusedMidway = DownloadFailure(
    DownloadFailureKind.refused,
    'YouTube cortó la descarga a mitad de camino. Al reintentar se prueba otra forma.',
  );
  static const noSpace = DownloadFailure(DownloadFailureKind.noSpace, 'No queda espacio en el dispositivo.');
  static const unknown = DownloadFailure(DownloadFailureKind.unknown, 'No se pudo descargar. Reintenta en un rato.');
  static const noAlternative = DownloadFailure(
    DownloadFailureKind.content,
    'Kiji no encontró otra versión de esta canción en YouTube Music.',
  );

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
        ContentProblem.ageRestricted =>
          'Tiene restricción de edad: YouTube no deja bajarla sin iniciar sesión. Puedes buscar otra versión.',
        ContentProblem.unavailable => 'YouTube Music ya no la ofrece (la quitaron o no está en tu país).',
        ContentProblem.private => 'El video es privado.',
        ContentProblem.removed => 'El video fue borrado de YouTube.',
        ContentProblem.regionBlocked => 'No está disponible en tu país.',
      };

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'message': message,
        if (problem != null) 'problem': problem!.name,
      };

  static DownloadFailure fromJson(Map<String, dynamic> json) => DownloadFailure(
        DownloadFailureKind.values.asNameMap()[json['kind']] ?? DownloadFailureKind.unknown,
        json['message'] as String? ?? unknown.message,
        problem: ContentProblem.values.asNameMap()[json['problem']],
      );
}
