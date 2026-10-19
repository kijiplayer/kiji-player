#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <tlhelp32.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Cierra las otras copias de kiji_player.exe (solo se usa si están trabadas).
void TerminateOtherInstances() {
  const DWORD self = ::GetCurrentProcessId();
  wchar_t own_path[MAX_PATH];
  ::GetModuleFileNameW(nullptr, own_path, MAX_PATH);
  const wchar_t* own_name = wcsrchr(own_path, L'\\');
  own_name = own_name ? own_name + 1 : own_path;
  HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return;
  PROCESSENTRY32W entry{sizeof(entry)};
  for (BOOL ok = ::Process32FirstW(snapshot, &entry); ok; ok = ::Process32NextW(snapshot, &entry)) {
    if (entry.th32ProcessID == self || _wcsicmp(entry.szExeFile, own_name) != 0) continue;
    HANDLE process = ::OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, entry.th32ProcessID);
    if (process) {
      ::TerminateProcess(process, 1);
      ::WaitForSingleObject(process, 3000);
      ::CloseHandle(process);
    }
  }
  ::CloseHandle(snapshot);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Una sola Kiji a la vez. Si ya hay una que dibujó su primer cuadro, se trae al frente y esta
  // termina. Si la otra quedó trabada antes de dibujar (pasaba: proceso invisible de 150-190 MB),
  // se cierra y esta arranca normalmente.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, FALSE, L"Local\\KijiPlayer.Instancia");
  if (instance_mutex && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HANDLE ready = ::OpenEventW(SYNCHRONIZE, FALSE, kFirstFrameEvent);
    const bool other_ready = ready && ::WaitForSingleObject(ready, 3000) == WAIT_OBJECT_0;
    if (ready) ::CloseHandle(ready);
    HWND other = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Kiji Player");
    if (other_ready && other) {
      ::ShowWindow(other, ::IsIconic(other) ? SW_RESTORE : SW_SHOW);
      ::SetForegroundWindow(other);
      return EXIT_SUCCESS;
    }
    TerminateOtherInstances();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Kiji Player", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
