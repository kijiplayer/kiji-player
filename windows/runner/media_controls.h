#ifndef RUNNER_MEDIA_CONTROLS_H_
#define RUNNER_MEDIA_CONTROLS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <atomic>
#include <memory>

// Mensajes propios de la ventana: los botones del sistema llegan en otro hilo y se pasan al de la
// ventana (el único que puede hablar con Flutter).
inline constexpr UINT kMediaButtonMessage = WM_APP + 0x4B1;
inline constexpr UINT kMediaSeekMessage = WM_APP + 0x4B2;

// Controles multimedia de Windows (SMTC): la ventanita de volumen, la pantalla de bloqueo, las
// teclas multimedia del teclado y los auriculares Bluetooth. Canal `kiji/media_controls`:
//   Dart → Windows: enable(bool), track({title, artist, album, art}), playback({playing,
//                   position, duration}) y clear().
//   Windows → Dart: button("play" | "pause" | "next" | "previous" | "stop") y seek(ms).
class MediaControls {
 public:
  MediaControls(flutter::BinaryMessenger* messenger, HWND window);
  ~MediaControls();

  // Devuelve true si el mensaje era de los controles.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  struct State;

  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<State> state_;
};

#endif  // RUNNER_MEDIA_CONTROLS_H_
