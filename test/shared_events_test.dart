import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/utils/shared_events.dart';

/// Un lado nativo falso que se porta como el de Android: un solo oyente por canal; un "listen"
/// nuevo reemplaza al anterior y "cancel" sin oyente responde "No active stream to cancel".
class _FakeNative {
  _FakeNative(this.name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(name, _handle);
  }

  final String name;
  bool active = false;
  int listens = 0;
  int cancels = 0;
  int errors = 0;
  static const _codec = StandardMethodCodec();

  Future<ByteData?> _handle(ByteData? message) async {
    final call = _codec.decodeMethodCall(message);
    switch (call.method) {
      case 'listen':
        listens++;
        active = true;
        return _codec.encodeSuccessEnvelope(null);
      case 'cancel':
        if (!active) {
          errors++;
          return _codec.encodeErrorEnvelope(code: 'error', message: 'No active stream to cancel');
        }
        cancels++;
        active = false;
        return _codec.encodeSuccessEnvelope(null);
    }
    return null;
  }

  void dispose() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(name, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Los errores que Flutter informa (los que llegaban a "Algo falló en la pantalla").
  List<FlutterErrorDetails> catchErrors() {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    return reported;
  }

  test('así fallaba: dos pantallas con su propio receiveBroadcastStream terminan en "No active stream"', () async {
    final native = _FakeNative('prueba/vieja');
    addTearDown(native.dispose);
    final reported = catchErrors();
    const channel = EventChannel('prueba/vieja');
    final a = channel.receiveBroadcastStream().listen((_) {});
    final b = channel.receiveBroadcastStream().listen((_) {});
    await pumpEventQueue();
    await a.cancel();
    await b.cancel();
    await pumpEventQueue();
    expect(native.errors, 1);
    expect(reported.single.exception.toString(), contains('No active stream to cancel'));
  });

  test('con el flujo compartido: un solo listen y un solo cancel, sin errores, aunque se vuelva a abrir', () async {
    final native = _FakeNative('prueba/compartida');
    addTearDown(native.dispose);
    final reported = catchErrors();
    final shared = SharedEvents('prueba/compartida');

    // Dos pantallas a la vez (el reproductor que se abre mientras otro se cierra).
    final a = shared.stream.listen((_) {});
    final b = shared.stream.listen((_) {});
    await pumpEventQueue();
    expect(native.listens, 1);
    await a.cancel();
    await pumpEventQueue();
    expect(native.cancels, 0, reason: 'todavía queda una pantalla escuchando');
    await b.cancel();
    await pumpEventQueue();
    expect(native.cancels, 1);

    // Se vuelve a abrir y a cerrar: otro listen y otro cancel, en orden.
    final c = shared.stream.listen((_) {});
    await pumpEventQueue();
    await c.cancel();
    await pumpEventQueue();
    expect([native.listens, native.cancels, native.errors], [2, 2, 0]);
    expect(reported, isEmpty);
  });

  test('los canales de Kiji usan el flujo compartido (siempre el mismo)', () {
    expect(identical(SharedEvents.tilt.stream, SharedEvents.tilt.stream), isTrue);
    expect(identical(SharedEvents.volume.stream, SharedEvents.volume.stream), isTrue);
  });
}
