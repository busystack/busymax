#include "notification_activation.h"

#include <set>

namespace busymax::activation {

bool DecodeJsonString(const std::string& encoded, std::string* decoded) {
  decoded->clear();
  decoded->reserve(encoded.size());
  for (size_t index = 0; index < encoded.size(); ++index) {
    const unsigned char character = encoded[index];
    if (character < 0x20 || character == '"') return false;
    if (character != '\\') {
      decoded->push_back(static_cast<char>(character));
      continue;
    }
    if (++index >= encoded.size()) return false;
    switch (encoded[index]) {
      case '\\':
      case '"':
      case '/':
        decoded->push_back(encoded[index]);
        break;
      case 'b':
        decoded->push_back('\b');
        break;
      case 'f':
        decoded->push_back('\f');
        break;
      case 'n':
        decoded->push_back('\n');
        break;
      case 'r':
        decoded->push_back('\r');
        break;
      case 't':
        decoded->push_back('\t');
        break;
      default:
        // BusyMax's encoder preserves UTF-8 directly and never emits \u
        // escapes, so accepting them would unnecessarily widen the IPC
        // language beyond messages this runner can produce.
        return false;
    }
  }
  return !decoded->empty() && decoded->find('\0') == std::string::npos;
}

namespace {

bool ValidDate(const std::string& value) {
  if (value.size() != 10 || value[4] != '-' || value[7] != '-') return false;
  for (size_t i = 0; i < value.size(); ++i) {
    if (i != 4 && i != 7 && (value[i] < '0' || value[i] > '9')) return false;
  }
  const int year = std::stoi(value.substr(0, 4));
  const int month = std::stoi(value.substr(5, 2));
  const int day = std::stoi(value.substr(8, 2));
  const bool leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  const int days[] = {31, leap ? 29 : 28, 31, 30, 31, 30,
                      31, 31, 30, 31, 30, 31};
  return month >= 1 && month <= 12 && day >= 1 && day <= days[month - 1];
}

bool ParseJsonString(const std::string& json, size_t* cursor,
                     std::string* decoded) {
  if (*cursor >= json.size() || json[*cursor] != '"') return false;
  const size_t start = ++(*cursor);
  while (*cursor < json.size()) {
    const unsigned char character = json[*cursor];
    if (character == '"') {
      const auto encoded = json.substr(start, *cursor - start);
      ++(*cursor);
      return DecodeJsonString(encoded, decoded);
    }
    if (character == '\\') {
      ++(*cursor);
      if (*cursor >= json.size()) return false;
    } else if (character < 0x20) {
      return false;
    }
    ++(*cursor);
  }
  return false;
}

}  // namespace

bool IsValidNotificationActivation(const std::string& activation) {
  if (activation.size() > 16 * 1024) return false;
  constexpr char kPrefix[] =
      R"({"version":1,"kind":"notification","action":)";
  constexpr char kPayloadPrefix[] = R"(,"payload":{)";
  if (activation.compare(0, sizeof(kPrefix) - 1, kPrefix) != 0) return false;

  size_t cursor = sizeof(kPrefix) - 1;
  std::string action;
  if (!ParseJsonString(activation, &cursor, &action) ||
      (action != "default" && action != "open" && action != "snooze" &&
       action != "dismiss") ||
      activation.compare(cursor, sizeof(kPayloadPrefix) - 1,
                         kPayloadPrefix) != 0) {
    return false;
  }
  cursor += sizeof(kPayloadPrefix) - 1;

  std::set<std::string> keys;
  std::string notification_route;
  std::string summary_date;
  while (cursor < activation.size() && activation[cursor] != '}') {
    std::string key;
    std::string value;
    if (!ParseJsonString(activation, &cursor, &key) ||
        cursor >= activation.size() || activation[cursor++] != ':' ||
        !ParseJsonString(activation, &cursor, &value) || value.empty() ||
        value.size() > 2048 || value.find_first_not_of(" \t\r\n") == std::string::npos ||
        (key != "notificationRoute" && key != "notificationScheduleId" &&
         key != "notificationGeneration" && key != "itemKind" &&
         key != "accountId" && key != "sourceId" && key != "itemId" && key != "date") ||
        !keys.insert(key).second) {
      return false;
    }
    if (key == "notificationRoute") notification_route = value;
    if (key == "date") summary_date = value;
    if (cursor < activation.size() && activation[cursor] == ',') {
      ++cursor;
      if (cursor >= activation.size() || activation[cursor] == '}') {
        return false;
      }
    } else {
      break;
    }
  }
  if (cursor + 2 != activation.size() || activation[cursor] != '}' ||
      activation[cursor + 1] != '}') {
    return false;
  }
  // Summaries and errors navigate without a reminder lifecycle. Keep this
  // contract separate so they cannot acquire Snooze/Dismiss or mixed payloads.
  if (keys.find("notificationRoute") != keys.end()) {
    const bool account_route = notification_route == "sync-failure" ||
                               notification_route == "conflict";
    const bool route_keys = (account_route && keys.size() == 1) ||
        (notification_route == "due-today" && keys.size() == 2 &&
          keys.count("date") == 1 && ValidDate(summary_date)) ||
        (account_route && keys.size() == 2 && keys.count("accountId") == 1);
    return route_keys && (action == "default" || action == "open") &&
           (notification_route == "due-today" ||
            notification_route == "sync-failure" ||
            notification_route == "conflict");
  }
  return keys.find("notificationScheduleId") != keys.end() && keys.count("date") == 0;
}

}  // namespace busymax::activation
