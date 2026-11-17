#ifndef RUNNER_APP_ICON_H_
#define RUNNER_APP_ICON_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

// "Ícono a juego con el estilo" (0.8.3): cambia el ícono de la ventana y de la barra de tareas al
// momento. Canal `kiji/icon`: "current" y "apply" (variante: "default", "nocturne", "graphite"…).
// Los .ico están en data/flutter_assets/assets/icons/windows/ (tool/make_style_icons.py).
class AppIcon {
 public:
  AppIcon(flutter::BinaryMessenger* messenger, HWND window);
  ~AppIcon();

 private:
  bool Apply(const std::string& variant);

  HWND window_;
  std::string current_ = "default";
  HICON big_ = nullptr;
  HICON small_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_APP_ICON_H_
