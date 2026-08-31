#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool notification_activation_server =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "----AppNotificationActivationServer") !=
      command_line_arguments.end();
  const std::string initial_activation =
      BuildBusyMaxActivation(command_line_arguments);
  BusyMaxSingleInstance single_instance;
  const bool notification_forwarder =
      !single_instance.IsPrimary() && notification_activation_server;
  if (!single_instance.IsPrimary() && !notification_forwarder) {
    single_instance.ForwardActivation(initial_activation);
    return EXIT_SUCCESS;
  }
  if (notification_forwarder) {
    // The notification package receives COM activation only after its Dart FFI
    // callback server starts. This private mode starts no BusyMax providers or
    // database; it validates and forwards the resulting activation, then exits.
    command_line_arguments.emplace_back("--busymax-notification-forwarder");
  }

  // Initialize COM, so that it is available for plugins and packaged Windows
  // APIs such as StartupTask.
  const HRESULT com_result =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  const bool start_hidden =
      initial_activation.find("\"kind\":\"startMinimized\"") !=
      std::string::npos;
  FlutterWindow window(
      project, {initial_activation}, start_hidden,
      [&single_instance](const std::string& activation) {
        return single_instance.ForwardActivation(activation);
      });
  if (single_instance.IsPrimary()) {
    single_instance.Start(
        [&window](std::string activation) {
          window.QueueActivation(std::move(activation));
        });
  }
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"BusyMax", origin, size)) {
    single_instance.Stop();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  single_instance.Stop();
  if (SUCCEEDED(com_result)) {
    ::CoUninitialize();
  }
  return EXIT_SUCCESS;
}
