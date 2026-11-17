#include "app_icon.h"

#include <flutter/standard_method_codec.h>

#include "resource.h"

namespace {

// La carpeta del .exe (ahí al lado está data/flutter_assets).
std::wstring ExeFolder() {
  wchar_t path[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring folder(path, length);
  const size_t slash = folder.find_last_of(L"\\/");
  return slash == std::wstring::npos ? folder : folder.substr(0, slash);
}

}  // namespace

AppIcon::AppIcon(flutter::BinaryMessenger* messenger, HWND window) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "kiji/icon", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "current") {
      result->Success(flutter::EncodableValue(current_));
      return;
    }
    if (call.method_name() == "apply") {
      std::string variant = "default";
      if (const auto* name = std::get_if<std::string>(call.arguments())) variant = *name;
      result->Success(flutter::EncodableValue(Apply(variant)));
      return;
    }
    result->NotImplemented();
  });
}

AppIcon::~AppIcon() {
  if (big_) ::DestroyIcon(big_);
  if (small_) ::DestroyIcon(small_);
}

bool AppIcon::Apply(const std::string& variant) {
  // Solo letras: nada de rutas raras.
  for (const char c : variant) {
    if (c < 'a' || c > 'z') return false;
  }
  HICON big = nullptr;
  HICON small_icon = nullptr;
  const int big_size = ::GetSystemMetrics(SM_CXICON);
  const int small_size = ::GetSystemMetrics(SM_CXSMICON);
  if (variant == "default") {
    HINSTANCE instance = ::GetModuleHandle(nullptr);
    big = static_cast<HICON>(::LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, big_size, big_size, 0));
    small_icon = static_cast<HICON>(::LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, small_size, small_size, 0));
  } else {
    const std::wstring path = ExeFolder() + L"\\data\\flutter_assets\\assets\\icons\\windows\\kiji_" +
                              std::wstring(variant.begin(), variant.end()) + L".ico";
    big = static_cast<HICON>(::LoadImageW(nullptr, path.c_str(), IMAGE_ICON, big_size, big_size, LR_LOADFROMFILE));
    small_icon = static_cast<HICON>(::LoadImageW(nullptr, path.c_str(), IMAGE_ICON, small_size, small_size, LR_LOADFROMFILE));
  }
  if (!big || !small_icon) {
    if (big) ::DestroyIcon(big);
    if (small_icon) ::DestroyIcon(small_icon);
    return false;
  }
  ::SendMessageW(window_, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big));
  ::SendMessageW(window_, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(small_icon));
  // Los anteriores ya no los usa la ventana: se sueltan.
  if (big_) ::DestroyIcon(big_);
  if (small_) ::DestroyIcon(small_);
  big_ = big;
  small_ = small_icon;
  current_ = variant;
  return true;
}
