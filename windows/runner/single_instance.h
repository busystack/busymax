#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

enum class BusyMaxInstanceState {
  kPrimary,
  kSecondary,
  kFatalInitializationFailure,
};

struct BusyMaxSingleInstanceNativeHooks {
  std::function<std::wstring()> current_user_sid;
  std::function<HANDLE(const wchar_t*)> create_mutex;
  std::function<DWORD()> last_error;
  std::function<HANDLE(const wchar_t*, SECURITY_ATTRIBUTES*)> create_pipe;
  std::function<void(HANDLE)> close_handle;
};

BusyMaxSingleInstanceNativeHooks DefaultBusyMaxSingleInstanceNativeHooks();

class BusyMaxSingleInstance {
 public:
  BusyMaxSingleInstance();
  explicit BusyMaxSingleInstance(BusyMaxSingleInstanceNativeHooks hooks);
  ~BusyMaxSingleInstance();

  BusyMaxSingleInstance(const BusyMaxSingleInstance&) = delete;
  BusyMaxSingleInstance& operator=(const BusyMaxSingleInstance&) = delete;

  BusyMaxInstanceState state() const;
  bool IsPrimary() const;
  const std::string& initialization_error() const;
  bool ForwardActivation(const std::string& activation) const;
  bool Start(std::function<void(std::string)> on_activation,
             std::function<void()> on_listener_failure = {});
  void Stop();

 private:
  void Listen();
  HANDLE CreateSecuredPipe(SECURITY_ATTRIBUTES* attributes) const;
  void CompleteListenerStartup(bool succeeded, std::string error);

  HANDLE mutex_ = nullptr;
  std::wstring pipe_name_;
  std::wstring user_sid_;
  BusyMaxInstanceState state_ =
      BusyMaxInstanceState::kFatalInitializationFailure;
  std::string initialization_error_;
  BusyMaxSingleInstanceNativeHooks hooks_;
  std::atomic<bool> stopping_ = false;
  std::function<void(std::string)> on_activation_;
  std::function<void()> on_listener_failure_;
  std::thread listener_;
  std::mutex listener_start_mutex_;
  std::condition_variable listener_start_condition_;
  bool listener_start_complete_ = false;
  bool listener_start_succeeded_ = false;
  std::string listener_start_error_;
};

std::string BuildBusyMaxActivation(
    const std::vector<std::string>& arguments);
bool IsValidBusyMaxActivation(const std::string& activation);

#endif  // RUNNER_SINGLE_INSTANCE_H_
