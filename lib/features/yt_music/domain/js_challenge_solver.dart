import 'package:kiji_player/l10n/l10n.dart';

/// Respuestas del solver: valor original → valor resuelto.
class ChallengeAnswers {
  const ChallengeAnswers({this.n = const {}, this.sig = const {}, this.error});

  final Map<String, String> n;
  final Map<String, String> sig;

  /// Por qué no se pudo resolver, en palabras simples (null si anduvo).
  final String? error;
}

/// Resuelve los desafíos de JavaScript del reproductor de YouTube (la firma
/// cifrada y el parámetro `n`) con el solver de yt-dlp. Interfaz propia
///: en Android, iOS, macOS y Windows corre en una WebView sin
/// ventana; donde no hay WebView, [isSupported] es false.
abstract class JsChallengeSolver {
  bool get isSupported;

  /// Resuelve [n] y [sig] con el reproductor [playerHash], cuyo código da
  /// [playerJs] (solo se pide si no está ya preparado).
  Future<ChallengeAnswers> solve({
    required String playerHash,
    required Future<String> Function() playerJs,
    List<String> n = const [],
    List<String> sig = const [],
  });
}

class UnsupportedChallengeSolver implements JsChallengeSolver {
  const UnsupportedChallengeSolver();

  @override
  bool get isSupported => false;

  @override
  Future<ChallengeAnswers> solve({
    required String playerHash,
    required Future<String> Function() playerJs,
    List<String> n = const [],
    List<String> sig = const [],
  }) async => ChallengeAnswers(error: tx.enEsteDispositivoNoHayWebview);
}
