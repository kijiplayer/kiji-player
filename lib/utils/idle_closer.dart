import 'dart:async';

/// Cierra algo caro (una WebView) cuando lleva [after] sin usarse. Cada uso llama a [touch], que
/// vuelve a empezar la cuenta. En Windows, cada WebView2 abierta son varios procesos de Edge
/// (cientos de MB): no tiene sentido tenerlas abiertas mientras no se usan.
class IdleCloser {
  IdleCloser(this.after, this.onIdle);

  final Duration after;
  final void Function() onIdle;
  Timer? _timer;

  void touch() {
    _timer?.cancel();
    _timer = Timer(after, onIdle);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
