#include "flutter_timezone_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <utility>

namespace flutter_timezone {

void FlutterTimezonePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_timezone",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<FlutterTimezonePlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

FlutterTimezonePlugin::FlutterTimezonePlugin()
    : owned_api_(std::make_unique<WindowsTimezoneNativeApi>()),
      api_(owned_api_.get()) {}

FlutterTimezonePlugin::FlutterTimezonePlugin(TimezoneNativeApi* api)
    : api_(api) {}

FlutterTimezonePlugin::~FlutterTimezonePlugin() = default;

void FlutterTimezonePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == kGetLocalTimezone) {
    GetLocalTimezone(std::move(result));
    return;
  }
  if (method_call.method_name() == kGetAvailableTimezones) {
    GetAvailableTimezones(std::move(result));
    return;
  }
  result->NotImplemented();
}

void FlutterTimezonePlugin::GetLocalTimezone(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (api_ == nullptr) {
    result->Error("timezone-native-api-unavailable",
                  "The Windows time-zone service is unavailable.");
    return;
  }
  const TimezoneOperationResult operation = ResolveLocalTimezone(*api_);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  result->Success(flutter::EncodableValue(operation.value));
}

void FlutterTimezonePlugin::GetAvailableTimezones(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (api_ == nullptr) {
    result->Error("timezone-native-api-unavailable",
                  "The Windows time-zone service is unavailable.");
    return;
  }
  const TimezoneOperationResult operation = EnumerateTimezones(*api_);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  flutter::EncodableList values;
  values.reserve(operation.values.size());
  for (const std::string& value : operation.values) {
    values.emplace_back(value);
  }
  result->Success(flutter::EncodableValue(values));
}

}  // namespace flutter_timezone
