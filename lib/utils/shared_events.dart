import 'package:flutter/services.dart';

/// Un `EventChannel` propio de Kiji, compartido por toda la app.
///
/// El lado nativo tiene un solo oyente por canal: si cada pantalla llamara a
/// `receiveBroadcastStream()` por su cuenta, el segundo "listen" reemplazaría al primero, el
/// primero al cerrarse cancelaría el del segundo y el segundo terminaría pidiendo cancelar algo que
/// ya no existe ("No active stream to cancel"). Con un único flujo compartido, el canal se
/// escucha una vez cuando llega el primero y se cancela una vez cuando se va el último, por más
/// que se suscriban y se vayan muchas pantallas.
class SharedEvents {
  SharedEvents(String name) : _channel = EventChannel(name);

  final EventChannel _channel;

  /// El flujo del canal (de difusión: lo pueden escuchar varios a la vez).
  late final Stream<dynamic> stream = _channel.receiveBroadcastStream();

  /// Inclinación del teléfono (reflejo del vidrio de Grafito).
  static final tilt = SharedEvents('kiji/tilt');

  /// Volumen de la música del sistema ("Pausar al silenciar").
  static final volume = SharedEvents('kiji/volume');
}
