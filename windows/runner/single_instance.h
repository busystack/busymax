#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <atomic>
#include <functional>
#include <string>
#include <thread>
#include <vector>

class BusyMaxSingleInstance {
 public:
  BusyMaxSingleInstance();
  ~BusyMaxSingleInstance();

  BusyMaxSingleInstance(const BusyMaxSingleInstance&) = delete;
  BusyMaxSingleInstance& operator=(const BusyMaxSingleInstance&) = delete;

  bool IsPrimary() const;
  bool ForwardActivation(const std::string& activation) const;
  bool Start(std::function<void(std::string)> on_activation);
  void Stop();

 private:
  void Listen();

  HANDLE mutex_ = nullptr;
  std::wstring pipe_name_;
  std::wstring user_sid_;
  bool primary_ = false;
  std::atomic<bool> stopping_ = false;
  std::function<void(std::string)> on_activation_;
  std::thread listener_;
};

std::string BuildBusyMaxActivation(
    const std::vector<std::string>& arguments);
bool IsValidBusyMaxActivation(const std::string& activation);

#endif  // RUNNER_SINGLE_INSTANCE_H_
