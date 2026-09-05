#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  FlutterWindow(const flutter::DartProject& project,
                std::vector<std::string> initial_activations,
                bool start_hidden,
                std::function<bool(const std::string&)> forward_activation);
  virtual ~FlutterWindow();

  void QueueActivation(std::string activation);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_channel_;
  std::mutex activation_mutex_;
  std::vector<std::string> pending_activations_;
  bool activation_ready_ = false;
  bool hide_on_close_ = false;
  bool quit_requested_ = false;
  bool start_hidden_ = false;
  std::function<bool(const std::string&)> forward_activation_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
