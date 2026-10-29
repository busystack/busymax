#include "windows_tray_channel.h"

#include <flutter/standard_method_codec.h>
#include <limits>
#include <string>

namespace busymax {
namespace {
std::optional<std::wstring> Wide(const std::string* value) {
  if (value == nullptr || value->size() > 32767 ||
      value->find('\0') != std::string::npos) return std::nullopt;
  if (value->empty()) return std::wstring();
  const int size = static_cast<int>(value->size());
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                        value->data(), size, nullptr, 0);
  if (count <= 0) return std::nullopt;
  std::wstring result(static_cast<size_t>(count), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value->data(), size,
                         result.data(), count) != count) return std::nullopt;
  return result;
}

const flutter::EncodableValue* Field(const flutter::EncodableMap& map,
                                     const char* key) {
  const auto found = map.find(flutter::EncodableValue(key));
  return found == map.end() ? nullptr : &found->second;
}
}  // namespace

WindowsTrayChannel::WindowsTrayChannel(flutter::BinaryMessenger* messenger,
                                       HWND window)
    : window_(window), taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")),
      icon_(api_), menu_(api_),
      channel_(std::make_unique<
          flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "busymax/windows/tray",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleCall(call, std::move(result));
  });
}

WindowsTrayChannel::~WindowsTrayChannel() {
  channel_->SetMethodCallHandler(nullptr);
}

void WindowsTrayChannel::ReportAvailability(const TrayOperationResult& operation) {
  flutter::EncodableMap value{
      {flutter::EncodableValue("available"),
       flutter::EncodableValue(icon_.available())}};
  if (!operation.succeeded) {
    value.emplace(flutter::EncodableValue("errorCode"),
                  flutter::EncodableValue(operation.error_code));
  }
  channel_->InvokeMethod("onTrayAvailabilityChanged",
                         std::make_unique<flutter::EncodableValue>(value));
}

void WindowsTrayChannel::ShowMenu() {
  const auto operation = menu_.Show(window_, true);
  if (!operation.succeeded) {
    flutter::EncodableMap error{
        {flutter::EncodableValue("errorCode"),
         flutter::EncodableValue(operation.error_code)}};
    channel_->InvokeMethod("onMenuFailure",
                           std::make_unique<flutter::EncodableValue>(error));
  }
}

std::optional<LRESULT> WindowsTrayChannel::HandleMessage(
    UINT message, WPARAM wparam, LPARAM lparam) {
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    // Explorer discarded its icons. Recover from our retained, owned handle.
    if (active_) ReportAvailability(icon_.Recover(window_));
    return std::nullopt;
  }
  if (message == kBusyMaxTrayCallbackMessage && TrayCallbackIconId(lparam) == 2) {
    const UINT event = TrayCallbackEvent(lparam);
    if (event == NIN_SELECT || event == NIN_KEYSELECT) {
      channel_->InvokeMethod("open", nullptr);
    } else if (event == WM_CONTEXTMENU) {
      ShowMenu();
    }
    return 0;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == 0 && lparam == 0 &&
      LOWORD(wparam) >= 0x5000 && LOWORD(wparam) < 0x6000) {
    channel_->InvokeMethod("command", std::make_unique<flutter::EncodableValue>(
        static_cast<int32_t>(LOWORD(wparam))));
    return 0;
  }
  return std::nullopt;
}

void WindowsTrayChannel::HandleCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  TrayOperationResult operation;
  if (method == "setIcon" || method == "setToolTip") {
    const auto text = Wide(std::get_if<std::string>(call.arguments()));
    if (!text) {
      result->Error("tray-invalid-arguments", "Expected valid UTF-8 text.");
      return;
    }
    operation = method == "setIcon" ? icon_.SetIcon(window_, *text)
                                     : icon_.SetTooltip(*text);
    if (method == "setIcon" && operation.succeeded) active_ = true;
  } else if (method == "setMenu") {
    const auto* rows = std::get_if<flutter::EncodableList>(call.arguments());
    if (rows == nullptr || rows->size() > 256) {
      result->Error("tray-invalid-arguments", "The tray menu is invalid.");
      return;
    }
    std::vector<TrayMenuItem> items;
    for (const auto& row : *rows) {
      const auto* map = std::get_if<flutter::EncodableMap>(&row);
      const auto* id_value = map == nullptr ? nullptr : Field(*map, "id");
      const auto* label_value = map == nullptr ? nullptr : Field(*map, "label");
      const auto* separator_value = map == nullptr ? nullptr : Field(*map, "separator");
      const auto* disabled_value = map == nullptr ? nullptr : Field(*map, "disabled");
      const auto* id = id_value == nullptr ? nullptr : std::get_if<int32_t>(id_value);
      const auto label = Wide(label_value == nullptr ? nullptr :
                               std::get_if<std::string>(label_value));
      const auto* separator = separator_value == nullptr ? nullptr :
                                 std::get_if<bool>(separator_value);
      const auto* disabled = disabled_value == nullptr ? nullptr :
                                std::get_if<bool>(disabled_value);
      if (id == nullptr || *id < 0x5000 || *id >= 0x6000 || !label ||
          separator == nullptr || disabled == nullptr) {
        result->Error("tray-invalid-arguments", "A tray menu item is invalid.");
        return;
      }
      TrayMenuItem item;
      item.id = *id;
      item.label = *label;
      item.type = *separator ? TrayMenuItemType::kSeparator : TrayMenuItemType::kNormal;
      item.disabled = *disabled;
      items.push_back(std::move(item));
    }
    operation = menu_.SetItems(items);
  } else if (method == "showMenu") {
    operation = menu_.Show(window_, true);
  } else if (method == "destroy") {
    active_ = false;
    operation = icon_.Destroy();
  } else {
    result->NotImplemented();
    return;
  }
  if (operation.succeeded) {
    result->Success();
  } else {
    result->Error(operation.error_code, operation.error_message);
  }
}
}  // namespace busymax
