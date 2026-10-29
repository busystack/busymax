#include "windows_timezone_channel.h"

namespace busymax {
void WindowsTimezoneChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const bool local = call.method_name() == kGetLocalTimezone;
  if (!local && call.method_name() != kGetAvailableTimezones) {
    result->NotImplemented();
    return;
  }
  if (api_ == nullptr) {
    result->Error("timezone-native-api-unavailable",
                  "The Windows time-zone service is unavailable.");
    return;
  }
  const auto operation = local ? ResolveLocalTimezone(*api_)
                               : EnumerateTimezones(*api_);
  if (!operation.succeeded) {
    result->Error(operation.error_code, operation.error_message);
    return;
  }
  if (local) {
    result->Success(flutter::EncodableValue(operation.value));
  } else {
    flutter::EncodableList values;
    for (const auto& value : operation.values) values.emplace_back(value);
    result->Success(flutter::EncodableValue(values));
  }
}
}  // namespace busymax
