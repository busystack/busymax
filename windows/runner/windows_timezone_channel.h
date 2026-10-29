#ifndef BUSYMAX_WINDOWS_TIMEZONE_CHANNEL_H_
#define BUSYMAX_WINDOWS_TIMEZONE_CHANNEL_H_

#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_result.h>
#include <memory>

#include "timezone_native_api.h"

namespace busymax {
constexpr char kGetLocalTimezone[] = "getLocalTimezone";
constexpr char kGetAvailableTimezones[] = "getAvailableTimezones";

// Application channel: never registers with or alters flutter_timezone.
class WindowsTimezoneChannel {
 public:
  explicit WindowsTimezoneChannel(TimezoneNativeApi* api) : api_(api) {}
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  TimezoneNativeApi* api_;
};
}  // namespace busymax
#endif
