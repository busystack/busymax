#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <functional>
#include <optional>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "windows_startup_task.h"

namespace {

constexpr char kDesktopChannel[] =
    "org.busystack.busymax/windows_desktop";
constexpr UINT kActivationMessage = WM_APP + 42;
constexpr UINT kUiTaskMessage = WM_APP + 43;
constexpr LONG kMinimumWidth = 900;
constexpr LONG kMinimumHeight = 600;

bool HasPackageIdentity() {
  UINT32 length = 0;
  const LONG result = GetCurrentPackageFullName(&length, nullptr);
  return result == ERROR_INSUFFICIENT_BUFFER && length > 0;
}

void PostUiTask(HWND window, std::function<void()> task) {
  auto* owned = new std::function<void()>(std::move(task));
  if (!PostMessage(window, kUiTaskMessage, 0,
                   reinterpret_cast<LPARAM>(owned))) {
    delete owned;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::vector<std::string> initial_activations,
                             bool start_hidden,
                             std::function<bool(const std::string&)>
                                 forward_activation)
    : project_(project),
      pending_activations_(std::move(initial_activations)),
      start_hidden_(start_hidden),
      forward_activation_(std::move(forward_activation)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kDesktopChannel,
          &flutter::StandardMethodCodec::GetInstance());
  desktop_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto& method = call.method_name();
        if (method == "hide") {
          ShowWindow(GetHandle(), SW_HIDE);
          result->Success();
          return;
        }
        if (method == "showAndFocus") {
          ShowWindow(GetHandle(), IsIconic(GetHandle()) ? SW_RESTORE : SW_SHOW);
          SetForegroundWindow(GetHandle());
          if (flutter_controller_ && flutter_controller_->view()) {
            SetFocus(flutter_controller_->view()->GetNativeWindow());
          }
          result->Success();
          return;
        }
        if (method == "isVisible") {
          result->Success(flutter::EncodableValue(
              static_cast<bool>(IsWindowVisible(GetHandle()))));
          return;
        }
        if (method == "hasPackageIdentity") {
          result->Success(flutter::EncodableValue(HasPackageIdentity()));
          return;
        }
        if (method == "reportNotificationActivationFailure") {
          MessageBoxW(
              GetHandle(),
              L"BusyMax could not deliver the selected notification action "
              L"to the running application. No calendar or task data was "
              L"changed by this process.",
              L"BusyMax notification error", MB_OK | MB_ICONERROR);
          result->Success();
          return;
        }
        if (method == "setHideOnClose") {
          const auto* enabled =
              std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_argument", "Expected a Boolean value.");
            return;
          }
          hide_on_close_ = *enabled;
          result->Success();
          return;
        }
        if (method == "quit") {
          quit_requested_ = true;
          result->Success();
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          return;
        }
        if (method == "takeInitialActivations") {
          flutter::EncodableList encoded;
          {
            std::scoped_lock lock(activation_mutex_);
            for (const auto& activation : pending_activations_) {
              encoded.emplace_back(activation);
            }
            pending_activations_.clear();
          }
          result->Success(flutter::EncodableValue(encoded));
          return;
        }
        if (method == "activationReady") {
          activation_ready_ = true;
          std::vector<std::string> queued;
          {
            std::scoped_lock lock(activation_mutex_);
            queued.swap(pending_activations_);
          }
          for (const auto& activation : queued) {
            desktop_channel_->InvokeMethod(
                "activation",
                std::make_unique<flutter::EncodableValue>(activation));
          }
          result->Success();
          return;
        }
        if (method == "forwardActivation") {
          const auto* activation =
              std::get_if<std::string>(call.arguments());
          if (activation == nullptr || !forward_activation_) {
            result->Error("invalid_argument",
                          "Expected an encoded BusyMax activation.");
            return;
          }
          result->Success(
              flutter::EncodableValue(forward_activation_(*activation)));
          return;
        }
        if (method == "getStartupTaskState") {
          const auto window = GetHandle();
          auto shared_result =
              std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                  std::move(result));
          GetBusyMaxStartupTaskStateAsync(
              [window, shared_result](std::string state) {
                PostUiTask(
                    window,
                    [shared_result, state = std::move(state)]() {
                      shared_result->Success(flutter::EncodableValue(state));
                    });
              });
          return;
        }
        if (method == "setStartupTaskEnabled") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_argument", "Expected a Boolean value.");
            return;
          }
          const auto window = GetHandle();
          auto shared_result =
              std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                  std::move(result));
          SetBusyMaxStartupTaskEnabledAsync(
              *enabled,
              [window, shared_result](bool succeeded, std::string error) {
                PostUiTask(
                    window,
                    [shared_result, succeeded, error = std::move(error)]() {
                      if (succeeded) {
                        shared_result->Success();
                      } else {
                        shared_result->Error("startup_task_failed", error);
                      }
                    });
              });
          return;
        }
        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (!start_hidden_) Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::QueueActivation(std::string activation) {
  if (GetHandle() == nullptr) {
    std::scoped_lock lock(activation_mutex_);
    pending_activations_.push_back(std::move(activation));
    return;
  }
  auto* owned = new std::string(std::move(activation));
  if (!PostMessage(GetHandle(), kActivationMessage, 0,
                   reinterpret_cast<LPARAM>(owned))) {
    delete owned;
  }
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (!quit_requested_ && hide_on_close_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_GETMINMAXINFO: {
      const UINT dpi = GetDpiForWindow(hwnd);
      auto* sizing = reinterpret_cast<MINMAXINFO*>(lparam);
      sizing->ptMinTrackSize.x = MulDiv(kMinimumWidth, dpi, 96);
      sizing->ptMinTrackSize.y = MulDiv(kMinimumHeight, dpi, 96);
      return 0;
    }
    case kActivationMessage: {
      std::unique_ptr<std::string> activation(
          reinterpret_cast<std::string*>(lparam));
      if (!activation_ready_ || desktop_channel_ == nullptr) {
        std::scoped_lock lock(activation_mutex_);
        pending_activations_.push_back(std::move(*activation));
      } else {
        desktop_channel_->InvokeMethod(
            "activation", std::make_unique<flutter::EncodableValue>(*activation));
      }
      return 0;
    }
    case kUiTaskMessage: {
      std::unique_ptr<std::function<void()>> task(
          reinterpret_cast<std::function<void()>*>(lparam));
      (*task)();
      return 0;
    }
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
