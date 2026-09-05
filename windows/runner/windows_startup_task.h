#ifndef RUNNER_WINDOWS_STARTUP_TASK_H_
#define RUNNER_WINDOWS_STARTUP_TASK_H_

#include <functional>
#include <string>

using BusyMaxStartupTaskStateCallback = std::function<void(std::string)>;
using BusyMaxStartupTaskChangeCallback =
    std::function<void(bool, std::string)>;

void GetBusyMaxStartupTaskStateAsync(BusyMaxStartupTaskStateCallback callback);
void SetBusyMaxStartupTaskEnabledAsync(
    bool enabled,
    BusyMaxStartupTaskChangeCallback callback);

#endif  // RUNNER_WINDOWS_STARTUP_TASK_H_
