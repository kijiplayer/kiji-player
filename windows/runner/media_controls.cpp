#include "media_controls.h"

#include "utils.h"

#include <flutter/standard_method_codec.h>
#include <unknwn.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <chrono>
#include <string>

namespace {

using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::MediaPlaybackType;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;
using winrt::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs;
using winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties;
using winrt::Windows::Media::PlaybackPositionChangeRequestedEventArgs;

std::wstring Wide(const std::string& text) {
  if (text.empty()) return std::wstring();
  int size = ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), wide.data(), size);
  return wide;
}

std::string Text(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return std::string();
  if (auto value = std::get_if<std::string>(&it->second)) return *value;
  return std::string();
}

int64_t Number(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return 0;
  if (auto value = std::get_if<int32_t>(&it->second)) return *value;
  if (auto value = std::get_if<int64_t>(&it->second)) return *value;
  return 0;
}

const char* ButtonName(WPARAM button) {
  switch (static_cast<SystemMediaTransportControlsButton>(button)) {
    case SystemMediaTransportControlsButton::Play: return "play";
    case SystemMediaTransportControlsButton::Pause: return "pause";
    case SystemMediaTransportControlsButton::Next: return "next";
    case SystemMediaTransportControlsButton::Previous: return "previous";
    case SystemMediaTransportControlsButton::Stop: return "stop";
    default: return nullptr;
  }
}

winrt::Windows::Foundation::TimeSpan Ms(int64_t ms) {
  return std::chrono::duration_cast<winrt::Windows::Foundation::TimeSpan>(std::chrono::milliseconds(ms));
}

}  // namespace

struct MediaControls::State {
  SystemMediaTransportControls smtc{nullptr};
  winrt::event_token button_token{};
  winrt::event_token seek_token{};
  // Cada canción nueva sube el número: una portada que termina de cargar tarde no pisa a la nueva.
  std::atomic<int> generation{0};
};

MediaControls::MediaControls(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window), state_(std::make_unique<State>()) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "kiji/media_controls", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { HandleCall(call, std::move(result)); });
  try {
    auto interop = winrt::get_activation_factory<SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
    winrt::check_hresult(interop->GetForWindow(window, winrt::guid_of<SystemMediaTransportControls>(),
                                               winrt::put_abi(state_->smtc)));
    auto& smtc = state_->smtc;
    smtc.IsPlayEnabled(true);
    smtc.IsPauseEnabled(true);
    smtc.IsNextEnabled(true);
    smtc.IsPreviousEnabled(true);
    smtc.IsStopEnabled(true);
    // Los botones llegan en otro hilo: se pasan a la ventana.
    state_->button_token = smtc.ButtonPressed(
        [window](const SystemMediaTransportControls&, const SystemMediaTransportControlsButtonPressedEventArgs& args) {
          ::PostMessage(window, kMediaButtonMessage, static_cast<WPARAM>(args.Button()), 0);
        });
    state_->seek_token = smtc.PlaybackPositionChangeRequested(
        [window](const SystemMediaTransportControls&, const PlaybackPositionChangeRequestedEventArgs& args) {
          auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(args.RequestedPlaybackPosition()).count();
          ::PostMessage(window, kMediaSeekMessage, 0, static_cast<LPARAM>(ms));
        });
  } catch (const winrt::hresult_error& error) {
    ::OutputDebugStringW((L"=== CONTROLES: SMTC no disponible: " + std::wstring(error.message()) + L" ===\n").c_str());
    state_->smtc = nullptr;
  }
}

MediaControls::~MediaControls() {
  if (!state_->smtc) return;
  try {
    state_->smtc.ButtonPressed(state_->button_token);
    state_->smtc.PlaybackPositionChangeRequested(state_->seek_token);
    state_->smtc.IsEnabled(false);
  } catch (...) {
    // Ya se está cerrando: no hay a quién avisar.
  }
}

bool MediaControls::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == kMediaButtonMessage) {
    if (auto name = ButtonName(wparam)) {
      channel_->InvokeMethod("button", std::make_unique<flutter::EncodableValue>(std::string(name)));
    }
    return true;
  }
  if (message == kMediaSeekMessage) {
    channel_->InvokeMethod("seek", std::make_unique<flutter::EncodableValue>(static_cast<int64_t>(lparam)));
    return true;
  }
  return false;
}

void MediaControls::HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto& smtc = state_->smtc;
  if (!smtc) {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  const auto& method = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  try {
    if (method == "enable") {
      const auto* on = std::get_if<bool>(call.arguments());
      smtc.IsEnabled(on && *on);
    } else if (method == "track" && args) {
      const int generation = ++state_->generation;
      auto updater = smtc.DisplayUpdater();
      updater.ClearAll();
      updater.Type(MediaPlaybackType::Music);
      auto music = updater.MusicProperties();
      music.Title(Wide(Text(*args, "title")));
      music.Artist(Wide(Text(*args, "artist")));
      music.AlbumTitle(Wide(Text(*args, "album")));
      updater.Update();
      // La portada: la misma dirección que ya usa Kiji para mostrarla, o un archivo del disco.
      const auto art = Wide(Text(*args, "art"));
      if (art.rfind(L"https://", 0) == 0) {
        updater.Thumbnail(winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(
            winrt::Windows::Foundation::Uri(art)));
        updater.Update();
      } else if (!art.empty()) {
        auto state = state_.get();
        winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(art).Completed(
            [state, generation, updater](const auto& operation, winrt::Windows::Foundation::AsyncStatus status) {
              if (status != winrt::Windows::Foundation::AsyncStatus::Completed) return;
              if (state->generation != generation) return;
              try {
                updater.Thumbnail(
                    winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromFile(operation.GetResults()));
                updater.Update();
              } catch (...) {
                // Sin portada: la canción se ve igual.
              }
            });
      }
    } else if (method == "playback" && args) {
      auto playing = args->find(flutter::EncodableValue("playing"));
      const bool is_playing = playing != args->end() && std::get_if<bool>(&playing->second) &&
                              std::get<bool>(playing->second);
      smtc.PlaybackStatus(is_playing ? MediaPlaybackStatus::Playing : MediaPlaybackStatus::Paused);
      const int64_t duration = Number(*args, "duration");
      if (duration > 0) {
        SystemMediaTransportControlsTimelineProperties timeline;
        timeline.StartTime(Ms(0));
        timeline.MinSeekTime(Ms(0));
        timeline.EndTime(Ms(duration));
        timeline.MaxSeekTime(Ms(duration));
        timeline.Position(Ms(Number(*args, "position")));
        smtc.UpdateTimelineProperties(timeline);
      }
    } else if (method == "clear") {
      ++state_->generation;
      smtc.DisplayUpdater().ClearAll();
      smtc.DisplayUpdater().Update();
      smtc.PlaybackStatus(MediaPlaybackStatus::Closed);
    } else {
      result->NotImplemented();
      return;
    }
    result->Success(flutter::EncodableValue(true));
  } catch (const winrt::hresult_error& error) {
    result->Error("smtc", Utf8FromUtf16(error.message().c_str()));
  }
}
