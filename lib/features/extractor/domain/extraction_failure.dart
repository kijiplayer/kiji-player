import 'package:kiji_player/l10n/l10n.dart';

/// De quién es la culpa cuando no sale el audio (Tarea Z8). La clave del "1 de 11": un problema
/// del CONTENIDO (la canción) nunca marca una FORMA como rota.
enum FailureScope {
  /// La canción: restricción de edad, no disponible, privada, borrada, bloqueada en el país.
  content,

  /// La forma de pedirla: control anti-bot, 403, corte en 1 MiB, sin formatos, descifrado.
  form,

  /// Sin conexión: no es culpa de nadie.
  network,
}

/// Qué le pasa a la canción, cuando el problema es del contenido.
enum ContentProblem { ageRestricted, unavailable, private, removed, regionBlocked }

/// Un fallo ya clasificado, con un texto simple para mostrar.
class ExtractionFailure {
  const ExtractionFailure(this.scope, this.message, {this.problem, this.confirmed = false});

  final FailureScope scope;
  final String message;
  final ContentProblem? problem;

  /// Lo confirmó un motor que ya probó todas sus formas (InnerTubeX).
  final bool confirmed;

  bool get isContent => scope == FailureScope.content;

  /// La restricción de edad tiene un texto propio y alcanza con una forma; "no disponible" o
  /// "privado" necesitan que coincidan dos formas (WEB_REMIX sin PO token dice "Video
  /// unavailable" de todo, aunque la canción se pueda escuchar).
  bool get isConclusive => confirmed || problem == ContentProblem.ageRestricted;

  @override
  String toString() => '${scope.name}${problem == null ? '' : '/${problem!.name}'}: $message';
}

bool _any(String text, List<String> needles) => needles.any(text.contains);

/// Clasifica el motivo que dio YouTube (o una forma) en inglés o en español.
ExtractionFailure classifyFailure(String raw) {
  final t = raw.toLowerCase();
  // Control anti-bot: es de la forma (la misma canción sale con otra), aunque diga "Sign in".
  if (_any(t, ['not a bot', 'no eres un bot', 'no soy un bot', 'bot_check'])) {
    return ExtractionFailure(FailureScope.form, tx.youtubePidioConfirmarQueNoEs);
  }
  if (_any(t, [
    'confirm your age',
    'age-restricted',
    'age restricted',
    'age_restricted',
    'inappropriate for some users',
    'confirma tu edad',
    'confirmar tu edad',
    'restricción de edad',
    'restringido por edad',
    'puede ser inadecuado',
    'content_check_required',
  ])) {
    return ExtractionFailure(FailureScope.content, tx.tieneRestriccionDeEdad, problem: ContentProblem.ageRestricted);
  }
  if (_any(t, ['private video', 'video is private', 'es privado', 'video privado'])) {
    return ExtractionFailure(FailureScope.content, tx.elVideoEsPrivado2, problem: ContentProblem.private);
  }
  if (_any(t, [
    'has been removed',
    'was removed',
    'terminated',
    'se eliminó',
    'fue eliminado',
    'ha sido eliminado',
    'cuenta cancelada',
  ])) {
    return ExtractionFailure(FailureScope.content, tx.elVideoFueBorrado, problem: ContentProblem.removed);
  }
  if (_any(t, ['in your country', 'not available in your', 'en tu país', 'en tu region', 'en tu región', 'blocked it in'])) {
    return ExtractionFailure(FailureScope.content, tx.estaBloqueadoEnTuPais, problem: ContentProblem.regionBlocked);
  }
  if (_any(t, ['video unavailable', 'this video is unavailable', 'unavailable', 'no está disponible', 'no disponible'])) {
    return ExtractionFailure(
      FailureScope.content,
      tx.youtubeDiceQueNoEstaDisponible,
      problem: ContentProblem.unavailable,
    );
  }
  if (_any(t, [
    // Los motivos que arma Kiji (en el idioma de la app) y los de las librerías.
    'sin conexión',
    tx.sinConexion.toLowerCase(),
    'no internet',
    'socketexception',
    'failed host lookup',
    'connection refused',
    'network',
  ])) {
    return ExtractionFailure(FailureScope.network, tx.sinConexion);
  }
  // Todo lo demás es de la forma: 403, corte en 1 MiB, sin formatos, solo SABR, descifrado…
  return ExtractionFailure(FailureScope.form, raw.isEmpty ? tx.falloEstaForma : raw);
}

/// Veredicto sobre la CANCIÓN después de probar varias formas: hay problema de contenido si
/// alguna dio un motivo concluyente (edad) o si dos o más coinciden en el mismo problema.
ContentProblem? contentVerdict(Iterable<ExtractionFailure> failures) {
  final content = [
    for (final f in failures)
      if (f.isContent) f,
  ];
  for (final f in content) {
    if (f.isConclusive) return f.problem;
  }
  final counts = <ContentProblem, int>{};
  for (final f in content) {
    counts.update(f.problem!, (n) => n + 1, ifAbsent: () => 1);
  }
  for (final entry in counts.entries) {
    if (entry.value >= 2) return entry.key;
  }
  return null;
}

/// Texto simple para la canción marcada (en Descargas, la cola y la Salud del Extractor).
String contentProblemText(ContentProblem problem) => switch (problem) {
  ContentProblem.ageRestricted => tx.requiereCuentaRestriccionDeEdad,
  ContentProblem.unavailable => tx.noEstaDisponibleEnYoutube,
  ContentProblem.private => tx.elVideoEsPrivado2,
  ContentProblem.removed => tx.elVideoFueBorrado,
  ContentProblem.regionBlocked => tx.bloqueadaEnTuPais,
};
