#ifndef RUNNER_NOTIFICATION_ACTIVATION_H_
#define RUNNER_NOTIFICATION_ACTIVATION_H_

#include <string>

namespace busymax::activation {

// The runner checks the complete activation's UTF-8 encoding and byte limit
// before parsing it. These platform-independent helpers validate its JSON and
// notification contract without requiring a Win32 process or named pipe.
bool DecodeJsonString(const std::string& encoded, std::string* decoded);
bool IsValidNotificationActivation(const std::string& activation);

}  // namespace busymax::activation

#endif  // RUNNER_NOTIFICATION_ACTIVATION_H_
