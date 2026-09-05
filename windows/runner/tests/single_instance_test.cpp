#include "../single_instance.h"

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void Check(bool condition, const char* description) {
  if (condition) return;
  ++failures;
  std::cerr << "FAILED: " << description << std::endl;
}

void TestActivationValidation() {
  Check(BuildBusyMaxActivation({"----AppNotificationActivationServer"}) ==
            R"({"version":1,"kind":"startMinimized"})",
        "notification forwarder starts hidden without opening application data");
  Check(IsValidBusyMaxActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "normal activation");
  Check(IsValidBusyMaxActivation(
            R"({"version":1,"kind":"icsFile","value":"C:\\Temp\\a.ics"})"),
        "ICS activation");
  Check(!IsValidBusyMaxActivation(
            R"({"version":1,"kind":"icsFile","value":"file:///C:/Temp/a.ics"})"),
        "file URI is not accepted as an ICS path");
  Check(IsValidBusyMaxActivation(
            R"({"version":1,"kind":"webCal","value":"webcal://example.test/a"})"),
        "webcal activation");
  Check(!IsValidBusyMaxActivation(
            R"({"version":1,"kind":"webCal","value":"webcal://user@example.test/a"})"),
        "webcal user information rejected");
  Check(!IsValidBusyMaxActivation(
            R"({"version":1,"kind":"webCal","value":"webcal://example.test/%zz"})"),
        "malformed webcal percent encoding rejected");
  Check(BuildBusyMaxActivation({"webcal://example.test/feed.ics"}) ==
            R"({"version":1,"kind":"webCal","value":"webcal://example.test/feed.ics"})",
        "webcal URI ending in ICS is not misclassified as a file path");
  Check(!IsValidBusyMaxActivation(std::string("\xC3\x28", 2)),
        "malformed UTF-8 rejected");
  Check(!IsValidBusyMaxActivation("not-json"), "malformed JSON rejected");
  Check(!IsValidBusyMaxActivation(std::string(16 * 1024 + 1, 'x')),
        "oversized activation rejected");
  Check(IsValidBusyMaxActivation(
            R"({"version":1,"kind":"notification","action":"snooze","payload":{"notificationScheduleId":"row-1","itemId":"item-1"}})"),
        "notification action allowlist accepted");
  Check(!IsValidBusyMaxActivation(
            R"({"version":1,"kind":"notification","action":"run-command","payload":{"notificationScheduleId":"row-1"}})"),
        "unknown notification action rejected");
}

void TestFatalInitializationStates() {
  auto sid_failure = DefaultBusyMaxSingleInstanceNativeHooks();
  sid_failure.current_user_sid = [] { return std::wstring(); };
  BusyMaxSingleInstance no_sid(std::move(sid_failure));
  Check(no_sid.state() ==
            BusyMaxInstanceState::kFatalInitializationFailure,
        "SID failure is fatal");

  auto mutex_failure = DefaultBusyMaxSingleInstanceNativeHooks();
  mutex_failure.create_mutex = [](const wchar_t*) -> HANDLE { return nullptr; };
  mutex_failure.last_error = [] { return ERROR_ACCESS_DENIED; };
  BusyMaxSingleInstance no_mutex(std::move(mutex_failure));
  Check(no_mutex.state() ==
            BusyMaxInstanceState::kFatalInitializationFailure,
        "mutex failure is fatal");
}

void TestListenerStartupAcknowledgmentFailure() {
  auto hooks = DefaultBusyMaxSingleInstanceNativeHooks();
  hooks.create_pipe = [](const wchar_t*, SECURITY_ATTRIBUTES*) {
    SetLastError(ERROR_ACCESS_DENIED);
    return INVALID_HANDLE_VALUE;
  };
  BusyMaxSingleInstance instance(std::move(hooks));
  if (instance.state() != BusyMaxInstanceState::kPrimary) {
    // A concurrently running BusyMax owns the real per-user mutex; this case is
    // covered by the installed-package integration harness instead.
    return;
  }
  Check(!instance.Start([](std::string) {}),
        "listener startup failure is acknowledged");
  Check(instance.state() ==
            BusyMaxInstanceState::kFatalInitializationFailure,
        "listener startup failure becomes fatal");
}

void TestSimultaneousStartAndPipeAcknowledgment() {
  BusyMaxSingleInstance primary;
  if (primary.state() != BusyMaxInstanceState::kPrimary) return;
  std::atomic<int> activations = 0;
  Check(primary.Start([&activations](std::string activation) {
          if (IsValidBusyMaxActivation(activation)) ++activations;
        }),
        "primary listener starts before application data");

  BusyMaxSingleInstance secondary;
  Check(secondary.state() == BusyMaxInstanceState::kSecondary,
        "simultaneous process is secondary");
  Check(secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "secondary receives pipe acknowledgment");
  const ULONGLONG deadline = GetTickCount64() + 1000;
  while (activations.load() == 0 && GetTickCount64() < deadline) Sleep(5);
  Check(activations.load() == 1, "primary receives one activation");

  primary.Stop();
  Check(!secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "terminating primary does not permit a second database writer");
}

void TestForwardingTimeoutIsBounded() {
  const std::wstring sid =
      L"BusyMaxNativeTimeoutTest-" + std::to_wstring(GetCurrentProcessId());
  const std::wstring pipe_name = L"\\\\.\\pipe\\BusyMax-Activation-" + sid;
  HANDLE server = CreateNamedPipeW(
      pipe_name.c_str(), PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
      1, 1, 16 * 1024 + sizeof(uint32_t), 5000, nullptr);
  Check(server != INVALID_HANDLE_VALUE, "timeout test creates stale pipe");
  if (server == INVALID_HANDLE_VALUE) return;

  std::thread hung_server([server] {
    if (ConnectNamedPipe(server, nullptr) ||
        GetLastError() == ERROR_PIPE_CONNECTED) {
      uint32_t length = 0;
      DWORD read = 0;
      ReadFile(server, &length, sizeof(length), &read, nullptr);
      std::vector<char> body(length);
      if (length > 0 && length <= 16 * 1024) {
        ReadFile(server, body.data(), length, &read, nullptr);
      }
      // Simulate a stale or terminating primary that accepted the activation
      // but never acknowledged it.
      Sleep(5500);
    }
    DisconnectNamedPipe(server);
    CloseHandle(server);
  });

  auto hooks = DefaultBusyMaxSingleInstanceNativeHooks();
  hooks.current_user_sid = [sid] { return sid; };
  hooks.create_mutex = [](const wchar_t*) {
    return CreateEventW(nullptr, TRUE, FALSE, nullptr);
  };
  hooks.last_error = [] { return ERROR_ALREADY_EXISTS; };
  BusyMaxSingleInstance secondary(std::move(hooks));
  const ULONGLONG started = GetTickCount64();
  Check(!secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "forwarding without acknowledgment fails");
  const ULONGLONG elapsed = GetTickCount64() - started;
  Check(elapsed >= 4000 && elapsed < 8000,
        "forwarding acknowledgment timeout is bounded");
  hung_server.join();
}

}  // namespace

int main() {
  TestActivationValidation();
  TestFatalInitializationStates();
  TestListenerStartupAcknowledgmentFailure();
  TestSimultaneousStartAndPipeAcknowledgment();
  TestForwardingTimeoutIsBounded();
  if (failures == 0) {
    std::cout << "BusyMax single-instance native tests passed." << std::endl;
  }
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
