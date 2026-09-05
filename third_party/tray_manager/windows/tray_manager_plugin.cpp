#include "include/tray_manager/tray_manager_plugin.h"

#include "tray_native_api.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <codecvt>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <utility>

#define WM_MYMESSAGE (WM_USER + 1)

namespace {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  const auto found = map.find(flutter::EncodableValue(key));
  return found == map.end() ? nullptr : &found->second;
}

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> health_channel;

class TrayManagerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);
  explicit TrayManagerPlugin(flutter::PluginRegistrarWindows* registrar);
  ~TrayManagerPlugin() override;

 private:
  flutter::PluginRegistrarWindows* registrar_;
  tray_manager::WindowsTrayNativeApi native_api_;
  tray_manager::TrayIconController tray_{native_api_};
  tray_manager::TrayMenuController menu_{native_api_};
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter_;
  UINT taskbar_created_message_ = 0;
  int window_proc_id_ = -1;

  HWND GetMainWindow() const;
  void ReportAvailability(const tray_manager::TrayOperationResult& operation);
  bool BuildMenu(const flutter::EncodableMap& args,
                 std::vector<tray_manager::TrayMenuItem>* menu,
                 std::string* error);
  std::optional<LRESULT> HandleWindowProc(HWND window,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Destroy(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetIcon(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetToolTip(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void PopUpContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetBounds(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

bool plugin_already_registered = false;

void TrayManagerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  if (plugin_already_registered) {
    return;
  }
  plugin_already_registered = true;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "tray_manager",
      &flutter::StandardMethodCodec::GetInstance());
  health_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "busymax/windows/tray_health",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<TrayManagerPlugin>(registrar);
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

TrayManagerPlugin::TrayManagerPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(window, message, wparam, lparam);
      });
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
}

TrayManagerPlugin::~TrayManagerPlugin() {
  tray_.Destroy();
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

HWND TrayManagerPlugin::GetMainWindow() const {
  return ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
}

void TrayManagerPlugin::ReportAvailability(
    const tray_manager::TrayOperationResult& operation) {
  if (!health_channel) {
    return;
  }
  flutter::EncodableMap event;
  event[flutter::EncodableValue("available")] =
      flutter::EncodableValue(tray_.available());
  if (!operation.succeeded) {
    event[flutter::EncodableValue("errorCode")] =
        flutter::EncodableValue(operation.error_code);
  }
  health_channel->InvokeMethod(
      "onTrayAvailabilityChanged",
      std::make_unique<flutter::EncodableValue>(event));
}

bool TrayManagerPlugin::BuildMenu(const flutter::EncodableMap& args,
                                  std::vector<tray_manager::TrayMenuItem>* menu,
                                  std::string* error) {
  const auto items_it = args.find(flutter::EncodableValue("items"));
  if (menu == nullptr || items_it == args.end() ||
      !std::holds_alternative<flutter::EncodableList>(items_it->second)) {
    *error = "tray-menu-invalid";
    return false;
  }
  const auto& items = std::get<flutter::EncodableList>(items_it->second);
  for (const flutter::EncodableValue& item_value : items) {
    if (!std::holds_alternative<flutter::EncodableMap>(item_value)) {
      *error = "tray-menu-item-invalid";
      return false;
    }
    const auto& item = std::get<flutter::EncodableMap>(item_value);
    try {
      const int id =
          std::get<int>(item.at(flutter::EncodableValue("id")));
      const std::string type =
          std::get<std::string>(item.at(flutter::EncodableValue("type")));
      const std::string label =
          std::get<std::string>(item.at(flutter::EncodableValue("label")));
      const bool disabled =
          std::get<bool>(item.at(flutter::EncodableValue("disabled")));
      tray_manager::TrayMenuItem parsed;
      parsed.id = id;
      parsed.label = converter_.from_bytes(label);
      parsed.disabled = disabled;
      if (type == "separator") {
        parsed.type = tray_manager::TrayMenuItemType::kSeparator;
      } else if (type == "checkbox") {
        const bool* checked = std::get_if<bool>(ValueOrNull(item, "checked"));
        if (checked == nullptr) {
          *error = "tray-menu-checkbox-invalid";
          return false;
        }
        parsed.type = tray_manager::TrayMenuItemType::kCheckbox;
        parsed.checked = *checked;
      } else if (type == "submenu") {
        parsed.type = tray_manager::TrayMenuItemType::kSubmenu;
        const auto submenu_it = item.find(flutter::EncodableValue("submenu"));
        if (submenu_it == item.end() ||
            !std::holds_alternative<flutter::EncodableMap>(submenu_it->second) ||
            !BuildMenu(std::get<flutter::EncodableMap>(submenu_it->second),
                       &parsed.children, error)) {
          return false;
        }
      } else if (type != "normal") {
        *error = "tray-menu-type-invalid";
        return false;
      }
      menu->push_back(std::move(parsed));
    } catch (const std::exception&) {
      *error = "tray-menu-value-invalid";
      return false;
    }
  }
  return true;
}

std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc(HWND window,
                                                           UINT message,
                                                           WPARAM wparam,
                                                           LPARAM lparam) {
  if (message == WM_DESTROY) {
    const auto operation = tray_.Destroy();
    ReportAvailability(operation);
  } else if (message == WM_COMMAND) {
    flutter::EncodableMap event;
    event[flutter::EncodableValue("id")] =
        flutter::EncodableValue(static_cast<int>(LOWORD(wparam)));
    channel->InvokeMethod("onTrayMenuItemClick",
                          std::make_unique<flutter::EncodableValue>(event));
  } else if (message == WM_MYMESSAGE) {
    if (tray_manager::TrayCallbackIconId(lparam) != 1) {
      return std::nullopt;
    }
    const UINT event = tray_manager::TrayCallbackEvent(lparam);
    if (event == WM_LBUTTONUP || event == NIN_SELECT ||
        event == NIN_KEYSELECT) {
      channel->InvokeMethod("onTrayIconMouseDown",
                            std::make_unique<flutter::EncodableValue>());
    } else if (event == WM_RBUTTONUP || event == WM_CONTEXTMENU) {
      channel->InvokeMethod("onTrayIconRightMouseDown",
                            std::make_unique<flutter::EncodableValue>());
    }
  } else if (message == taskbar_created_message_ &&
             taskbar_created_message_ != 0) {
    const auto operation = tray_.Recover(GetMainWindow());
    ReportAvailability(operation);
  } else if (message == WM_POWERBROADCAST &&
             (wparam == PBT_APMRESUMEAUTOMATIC ||
              wparam == PBT_APMRESUMESUSPEND) &&
             tray_.available()) {
    const auto operation = tray_.Recover(GetMainWindow());
    ReportAvailability(operation);
  }
  return std::nullopt;
}

void TrayManagerPlugin::Destroy(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto operation = tray_.Destroy();
  ReportAvailability(operation);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetIcon(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    const std::string path =
        std::get<std::string>(args.at(flutter::EncodableValue("iconPath")));
    const auto operation = tray_.SetIcon(GetMainWindow(),
                                         converter_.from_bytes(path));
    ReportAvailability(operation);
    if (!operation.succeeded) {
      result->Error(operation.error_code, operation.error_message);
      return;
    }
    result->Success(flutter::EncodableValue(true));
  } catch (const std::exception&) {
    result->Error("tray-icon-arguments-invalid",
                  "The BusyMax tray icon path was invalid.");
  }
}

void TrayManagerPlugin::SetToolTip(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    const std::string tooltip =
        std::get<std::string>(args.at(flutter::EncodableValue("toolTip")));
    const auto operation = tray_.SetTooltip(converter_.from_bytes(tooltip));
    if (!operation.succeeded) {
      result->Error(operation.error_code, operation.error_message);
      return;
    }
    result->Success(flutter::EncodableValue(true));
  } catch (const std::exception&) {
    result->Error("tray-tooltip-invalid",
                  "The BusyMax tray tooltip was invalid.");
  }
}

void TrayManagerPlugin::SetContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<tray_manager::TrayMenuItem> parsed;
  std::string error;
  try {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    const auto& menu_args = std::get<flutter::EncodableMap>(
        args.at(flutter::EncodableValue("menu")));
    if (!BuildMenu(menu_args, &parsed, &error)) {
      result->Error(error, "Windows could not build the BusyMax tray menu.");
      return;
    }
  } catch (const std::exception&) {
    result->Error("tray-menu-arguments-invalid",
                  "The BusyMax tray menu was invalid.");
    return;
  }
  const auto operation = menu_.SetItems(parsed);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::PopUpContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!tray_.available() || !menu_.available()) {
    result->Error("tray-menu-unavailable",
                  "The BusyMax tray menu is not available.");
    return;
  }
  bool bring_to_front = false;
  try {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    bring_to_front = std::get<bool>(
        args.at(flutter::EncodableValue("bringAppToFront")));
  } catch (const std::exception&) {
    result->Error("tray-menu-arguments-invalid",
                  "The BusyMax tray menu request was invalid.");
    return;
  }
  const auto operation = menu_.Show(GetMainWindow(), bring_to_front);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::GetBounds(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  double scale = 0;
  try {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    scale = std::get<double>(
        args.at(flutter::EncodableValue("devicePixelRatio")));
  } catch (const std::exception&) {
    result->Error("tray-bounds-arguments-invalid",
                  "The BusyMax tray scale value was invalid.");
    return;
  }
  if (scale <= 0) {
    result->Error("tray-bounds-scale-invalid",
                  "The BusyMax tray scale value must be positive.");
    return;
  }
  RECT rect{};
  const auto operation = tray_.GetBounds(&rect);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  flutter::EncodableMap bounds;
  bounds[flutter::EncodableValue("x")] =
      flutter::EncodableValue(rect.left / scale);
  bounds[flutter::EncodableValue("y")] =
      flutter::EncodableValue(rect.top / scale);
  bounds[flutter::EncodableValue("width")] =
      flutter::EncodableValue((rect.right - rect.left) / scale);
  bounds[flutter::EncodableValue("height")] =
      flutter::EncodableValue((rect.bottom - rect.top) / scale);
  result->Success(flutter::EncodableValue(bounds));
}

void TrayManagerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& name = method_call.method_name();
  if (name == "destroy") {
    Destroy(std::move(result));
  } else if (name == "setIcon") {
    SetIcon(method_call, std::move(result));
  } else if (name == "setToolTip") {
    SetToolTip(method_call, std::move(result));
  } else if (name == "setContextMenu") {
    SetContextMenu(method_call, std::move(result));
  } else if (name == "popUpContextMenu") {
    PopUpContextMenu(method_call, std::move(result));
  } else if (name == "getBounds") {
    GetBounds(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void TrayManagerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  TrayManagerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
