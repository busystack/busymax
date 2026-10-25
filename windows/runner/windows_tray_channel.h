#ifndef BUSYMAX_WINDOWS_TRAY_CHANNEL_H_
#define BUSYMAX_WINDOWS_TRAY_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>
#include <optional>

#include "tray_native_api.h"

namespace busymax {
// Owns BusyMax's notification icon and menu through documented Win32 APIs.
// This channel is separate from the unchanged upstream tray_manager plugin.
class WindowsTrayChannel {
 public:
  WindowsTrayChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsTrayChannel();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                      LPARAM lparam);

 private:
  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReportAvailability(const TrayOperationResult& operation);
  void ShowMenu();

  HWND window_;
  UINT taskbar_created_;
  bool active_ = false;
  WindowsTrayNativeApi api_;
  TrayIconController icon_;
  TrayMenuController menu_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
}  // namespace busymax
#endif
