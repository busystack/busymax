#include "windows_startup_task.h"

#include <windows.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.h>

namespace {

constexpr wchar_t kStartupTaskId[] = L"BusyMaxStartupTask";

bool HasPackageIdentity() {
  UINT32 length = 0;
  const LONG result = GetCurrentPackageFullName(&length, nullptr);
  return result == ERROR_INSUFFICIENT_BUFFER;
}

std::string StateName(
    winrt::Windows::ApplicationModel::StartupTaskState state) {
  using State = winrt::Windows::ApplicationModel::StartupTaskState;
  switch (state) {
    case State::Enabled:
      return "enabled";
    case State::Disabled:
      return "disabled";
    case State::DisabledByUser:
      return "disabledByUser";
    case State::DisabledByPolicy:
      return "disabledByPolicy";
    default:
      return "unavailable";
  }
}

}  // namespace

void GetBusyMaxStartupTaskStateAsync(BusyMaxStartupTaskStateCallback callback) {
  if (!HasPackageIdentity()) {
    callback("unavailable");
    return;
  }
  try {
    auto operation =
        winrt::Windows::ApplicationModel::StartupTask::GetAsync(kStartupTaskId);
    operation.Completed(
        [callback](
            const auto& completed,
            winrt::Windows::Foundation::AsyncStatus status) mutable {
          if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
            callback("unavailable");
            return;
          }
          try {
            callback(StateName(completed.GetResults().State()));
          } catch (...) {
            callback("unavailable");
          }
        });
  } catch (...) {
    callback("unavailable");
  }
}

void SetBusyMaxStartupTaskEnabledAsync(
    bool enabled,
    BusyMaxStartupTaskChangeCallback callback) {
  if (!HasPackageIdentity()) {
    callback(false, "BusyMax is not running with package identity.");
    return;
  }
  try {
    auto operation =
        winrt::Windows::ApplicationModel::StartupTask::GetAsync(kStartupTaskId);
    operation.Completed(
        [enabled, callback](
            const auto& completed,
            winrt::Windows::Foundation::AsyncStatus status) mutable {
          if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
            callback(false, "Windows StartupTask lookup failed.");
            return;
          }
          try {
            const auto task = completed.GetResults();
            if (!enabled) {
              task.Disable();
              callback(true, "");
              return;
            }
            auto request = task.RequestEnableAsync();
            request.Completed(
                [callback](
                    const auto& enabled_operation,
                    winrt::Windows::Foundation::AsyncStatus enabled_status) {
                  if (enabled_status !=
                      winrt::Windows::Foundation::AsyncStatus::Completed) {
                    callback(false, "Windows did not enable the StartupTask.");
                    return;
                  }
                  try {
                    const auto state = enabled_operation.GetResults();
                    callback(
                        state == winrt::Windows::ApplicationModel::
                                     StartupTaskState::Enabled,
                        state == winrt::Windows::ApplicationModel::
                                     StartupTaskState::Enabled
                            ? ""
                            : "Windows did not enable the StartupTask.");
                  } catch (...) {
                    callback(false, "Windows StartupTask operation failed.");
                  }
                });
          } catch (...) {
            callback(false, "Windows StartupTask operation failed.");
          }
        });
  } catch (...) {
    callback(false, "Windows StartupTask operation failed.");
  }
}
