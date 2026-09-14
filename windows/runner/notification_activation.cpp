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
  while (cursor < activation.size() && activation[cursor] != '}') {
    std::string key;
    std::string value;
    if (!ParseJsonString(activation, &cursor, &key) ||
        cursor >= activation.size() || activation[cursor++] != ':' ||
        !ParseJsonString(activation, &cursor, &value) || value.empty() ||
        value.size() > 2048 ||
        (key != "notificationRoute" && key != "notificationScheduleId" &&
         key != "notificationGeneration" && key != "itemKind" &&
         key != "accountId" && key != "sourceId" && key != "itemId") ||
        !keys.insert(key).second) {
      return false;
    }
    if (key == "notificationRoute") notification_route = value;
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
    return keys.size() == 1 && (action == "default" || action == "open") &&
           (notification_route == "due-today" ||
            notification_route == "sync-failure" ||
            notification_route == "conflict");
  }
  return keys.find("notificationScheduleId") != keys.end();
}

}  // namespace busymax::activation
