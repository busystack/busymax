#include "../notification_activation.h"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

int failures = 0;

void Check(bool condition, const std::string& description) {
  if (condition) return;
  ++failures;
  std::cerr << "FAILED: " << description << std::endl;
}

std::string Activation(const std::string& action, const std::string& payload) {
  return R"({"version":1,"kind":"notification","action":")" + action +
         R"(","payload":{)" + payload + "}}";
}

void TestRoutedNotifications() {
  using busymax::activation::IsValidNotificationActivation;
  for (const std::string route : {"due-today", "sync-failure", "conflict"}) {
    const std::string payload = R"("notificationRoute":")" + route + '"';
    for (const std::string action : {"default", "open"}) {
      Check(IsValidNotificationActivation(Activation(action, payload)),
            route + " accepts " + action);
    }
    for (const std::string action : {"snooze", "dismiss", "run-command", ""}) {
      Check(!IsValidNotificationActivation(Activation(action, payload)),
            route + " rejects " + action);
    }
    for (const std::string key : {"notificationScheduleId",
                                 "notificationGeneration", "itemKind",
                                 "accountId", "sourceId", "itemId", "unknown"}) {
      const std::string extra = '"' + key + R"(":"value")";
      Check(!IsValidNotificationActivation(
                Activation("open", payload + ',' + extra)),
            route + " rejects extra " + key);
      Check(!IsValidNotificationActivation(
                Activation("open", extra + ',' + payload)),
            route + " rejects preceding " + key);
    }
    Check(!IsValidNotificationActivation(
              Activation("open", payload + ',' + payload)),
          route + " rejects duplicate route keys");
    Check(!IsValidNotificationActivation(Activation("open", payload + ',')),
          route + " rejects a trailing comma");
    const auto activation = Activation("open", payload);
    Check(!IsValidNotificationActivation(activation + '}'),
          route + " rejects trailing JSON");
    Check(!IsValidNotificationActivation(
              activation.substr(0, activation.size() - 1)),
          route + " rejects incomplete JSON");
  }
  for (const std::string route : {"unknown", "", "tasks", "settings",
                                 "Due-Today", "due-today "}) {
    Check(!IsValidNotificationActivation(Activation(
              "default", R"("notificationRoute":")" + route + '"')),
          "unrecognized route rejected: " + route);
  }
  for (const std::string value : {"null", "true", "1", "{}", "[]"}) {
    Check(!IsValidNotificationActivation(
              Activation("open", R"("notificationRoute":)" + value)),
          "non-string route rejected: " + value);
  }
}

void TestScheduledNotifications() {
  using busymax::activation::IsValidNotificationActivation;
  const std::string payload =
      R"("notificationScheduleId":"schedule-1","notificationGeneration":"delivery-1","itemKind":"task","accountId":"account-1","sourceId":"source-1","itemId":"task-1")";
  for (const std::string action : {"default", "open", "snooze", "dismiss"}) {
    Check(IsValidNotificationActivation(Activation(action, payload)),
          "scheduled reminder still accepts " + action);
  }
  for (const std::string invalid : {
           "", R"("itemId":"task-1")", R"("notificationScheduleId":"")",
           R"("notificationScheduleId":"row-1","unknown":"value")",
           R"("notificationScheduleId":"row-1","notificationScheduleId":"row-2")"}) {
    Check(!IsValidNotificationActivation(Activation("open", invalid)),
          "invalid scheduled reminder remains rejected: " + invalid);
  }
  Check(!IsValidNotificationActivation(Activation(
            "open", R"("notificationScheduleId":")" +
                        std::string(2049, 'x') + '"')),
        "oversized schedule identifier rejected");
  Check(!IsValidNotificationActivation(Activation("run-command", payload)),
        "unknown reminder action rejected");
}

}  // namespace

int main(int argc, char* argv[]) {
  // The Dart integration test supplies the actual activation produced from
  // plugin payloads here. Run the production parser, not a Dart reimplementation.
  if (argc == 3 && std::string(argv[1]) == "--validate") {
    return busymax::activation::IsValidNotificationActivation(argv[2])
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
  }
  if (argc != 1) return EXIT_FAILURE;
  TestRoutedNotifications();
  TestScheduledNotifications();
  if (failures == 0) {
    std::cout << "BusyMax native notification activation tests passed."
              << std::endl;
  }
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
