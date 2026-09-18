#include "../single_instance.h"
#include "../clock_preference.h"
#include "../weekday_preference.h"

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <mutex>
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

std::wstring short_time_pattern;
std::wstring long_time_pattern;
bool fail_locale_read = false;

int WINAPI ReadTestLocale(LPCWSTR locale, LCTYPE type, LPWSTR output, int size) {
  Check(locale == LOCALE_NAME_USER_DEFAULT, "clock reads the user locale");
  if (fail_locale_read) return 0;
  // Deliberately implement the old long-time queries too: these regressions
  // must fail if the production reader goes back to either of those sources.
  std::wstring value;
  if (type == LOCALE_SSHORTTIME) {
    value = short_time_pattern;
  } else if (type == LOCALE_STIMEFORMAT) {
    value = long_time_pattern;
  } else if (type == LOCALE_ITIME) {
    value = BusyMaxShortTimeUses24Hours(long_time_pattern) == true ? L"1" : L"0";
  } else {
    Check(false, "unexpected locale query");
    return 0;
  }
  const int required = static_cast<int>(value.size()) + 1;
  if (size == 0) return required;
  if (size < required || !output) return 0;
  std::wmemcpy(output, value.c_str(), static_cast<std::size_t>(required));
  return required;
}

void TestPreferredShortTimeClock() {
  short_time_pattern = L"HH:mm";
  long_time_pattern = L"h:mm:ss tt";
  Check(BusyMaxRead24HourClock(&ReadTestLocale) == true,
        "24-hour short time wins over 12-hour long time");
  short_time_pattern = L"h:mm tt";
  long_time_pattern = L"HH:mm:ss";
  Check(BusyMaxRead24HourClock(&ReadTestLocale) == false,
        "12-hour short time wins over 24-hour long time");
  short_time_pattern = L"'h; o''clock' HH:mm;h:mm tt";
  Check(BusyMaxRead24HourClock(&ReadTestLocale) == true,
        "preferred short pattern ignores quoted literals and alternatives");
  short_time_pattern = L"'H; o''clock' h:mm tt;HH:mm";
  Check(BusyMaxRead24HourClock(&ReadTestLocale) == false,
        "preferred 12-hour short pattern ignores literal uppercase H");
  short_time_pattern = L"'HH:mm'";
  Check(!BusyMaxRead24HourClock(&ReadTestLocale).has_value(),
        "missing hour token does not fall back to the long clock");
  fail_locale_read = true;
  Check(!BusyMaxRead24HourClock(&ReadTestLocale).has_value(),
        "locale read failure remains unavailable");
  fail_locale_read = false;
}

DWORD test_first_weekday = 0;

int WINAPI ReadTestFirstWeekday(LPCWSTR locale, LCTYPE type, LPWSTR output,
                                int size) {
  Check(locale == LOCALE_NAME_USER_DEFAULT, "weekday reads the user locale");
  Check(type == (LOCALE_IFIRSTDAYOFWEEK | LOCALE_RETURN_NUMBER),
        "weekday requests the numeric user override");
  const int required = static_cast<int>(sizeof(DWORD) / sizeof(wchar_t));
  if (fail_locale_read || output == nullptr || size != required) return 0;
  *reinterpret_cast<DWORD*>(output) = test_first_weekday;
  return required;
}

void TestFirstWeekday() {
  for (DWORD windows_weekday = 0; windows_weekday < 7; windows_weekday++) {
    test_first_weekday = windows_weekday;
    Check(BusyMaxReadFirstWeekday(&ReadTestFirstWeekday) ==
              static_cast<int>(windows_weekday) + 1,
          "Windows weekday converts to Dart numbering");
  }
  test_first_weekday = 7;
  Check(!BusyMaxReadFirstWeekday(&ReadTestFirstWeekday).has_value(),
        "invalid Windows weekday is unavailable");
  fail_locale_read = true;
  Check(!BusyMaxReadFirstWeekday(&ReadTestFirstWeekday).has_value(),
        "weekday read failure is unavailable");
  fail_locale_read = false;
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
            R"({"version":1,"kind":"notification","action":"snooze","payload":{"notificationScheduleId":"row-1","notificationGeneration":"delivery-1","itemId":"item-1"}})"),
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
  std::mutex received_mutex;
  std::vector<std::string> received;
  Check(primary.Start([&](std::string activation) {
          if (IsValidBusyMaxActivation(activation)) {
            std::lock_guard<std::mutex> lock(received_mutex);
            received.push_back(activation);
            ++activations;
          }
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

  // Exercise both sender and receiver validation through the real named pipe.
  // These activations deliberately have no reminder schedule ID.
  int expected_count = 1;
  for (const std::string route : {"due-today", "sync-failure", "conflict"}) {
    for (const std::string action : {"default", "open"}) {
      const std::string activation =
          R"({"version":1,"kind":"notification","action":")" + action +
          R"(","payload":{"notificationRoute":")" + route + R"("}})";
      Check(IsValidBusyMaxActivation(activation),
            "runner accepts routed notification activation");
      Check(secondary.ForwardActivation(activation),
            "routed notification receives native pipe acknowledgment");
      ++expected_count;
      const ULONGLONG route_deadline = GetTickCount64() + 1000;
      while (activations.load() < expected_count &&
             GetTickCount64() < route_deadline) {
        Sleep(5);
      }
      Check(activations.load() == expected_count,
            "primary receives routed notification exactly once");
      std::lock_guard<std::mutex> lock(received_mutex);
      Check(!received.empty() && received.back() == activation,
            "native forwarding preserves exact routed payload");
    }
    for (const std::string action : {"snooze", "dismiss"}) {
      const std::string activation =
          R"({"version":1,"kind":"notification","action":")" + action +
          R"(","payload":{"notificationRoute":")" + route + R"("}})";
      Check(!secondary.ForwardActivation(activation),
            "native forwarding rejects reminder actions on summaries");
    }
    Check(!secondary.ForwardActivation(
              R"({"version":1,"kind":"notification","action":"open","payload":{"notificationRoute":")" +
              route + R"(","notificationScheduleId":"row-1"}})"),
          "native forwarding rejects mixed route/reminder payloads");
  }
  Check(!secondary.ForwardActivation(
            R"({"version":1,"kind":"notification","action":"open","payload":{"notificationRoute":"unknown"}})"),
        "native forwarding rejects unknown routes");
  Check(activations.load() == expected_count,
        "rejected notifications never reach the primary");

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
  TestPreferredShortTimeClock();
  TestFirstWeekday();
  Check(BusyMaxRead24HourClock().has_value(), "user clock preference can be read");
  Check(BusyMaxClockRefreshMessage(WM_SETTINGCHANGE, 0, reinterpret_cast<LPARAM>(L"intl")), "locale settings refresh the clock");
  Check(BusyMaxClockRefreshMessage(WM_SETTINGCHANGE, 0, 0), "unspecified settings refresh the clock");
  Check(!BusyMaxClockRefreshMessage(WM_SETTINGCHANGE, 0, reinterpret_cast<LPARAM>(L"Environment")), "unrelated settings do not refresh the clock");
  Check(BusyMaxClockRefreshMessage(WM_ACTIVATEAPP, TRUE, 0), "reactivation refreshes the clock");
  Check(!BusyMaxClockRefreshMessage(WM_ACTIVATEAPP, FALSE, 0), "deactivation does not refresh the clock");
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
