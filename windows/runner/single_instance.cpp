#include "single_instance.h"

#include <sddl.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <memory>
#include <set>
#include <system_error>
#include <utility>

namespace {

constexpr DWORD kMaximumActivationBytes = 16 * 1024;
constexpr DWORD kActivationConnectTimeoutMilliseconds = 5000;
constexpr wchar_t kPipePrefix[] = L"\\\\.\\pipe\\BusyMax-Activation-";
constexpr wchar_t kMutexPrefix[] = L"Local\\BusyMax-SingleInstance-";

HANDLE ConnectToActivationPipe(const std::wstring& pipe_name) {
  const ULONGLONG deadline =
      GetTickCount64() + kActivationConnectTimeoutMilliseconds;
  while (true) {
    HANDLE pipe = CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE,
                              0, nullptr, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) return pipe;

    const DWORD error = GetLastError();
    if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PIPE_BUSY) {
      return INVALID_HANDLE_VALUE;
    }
    const ULONGLONG now = GetTickCount64();
    if (now >= deadline) return INVALID_HANDLE_VALUE;
    const DWORD remaining = static_cast<DWORD>(deadline - now);

    if (error == ERROR_PIPE_BUSY) {
      if (!WaitNamedPipeW(pipe_name.c_str(), remaining)) {
        const DWORD wait_error = GetLastError();
        if (wait_error != ERROR_FILE_NOT_FOUND &&
            wait_error != ERROR_SEM_TIMEOUT) {
          return INVALID_HANDLE_VALUE;
        }
      }
    } else {
      // A newly elected primary owns the mutex before its listener thread has
      // created the first pipe instance. Retry that short startup window.
      Sleep(std::min<DWORD>(remaining, 25));
    }
  }
}

bool ReadExact(HANDLE pipe, void* destination, DWORD bytes) {
  auto* cursor = static_cast<unsigned char*>(destination);
  DWORD total = 0;
  while (total < bytes) {
    DWORD read = 0;
    if (!ReadFile(pipe, cursor + total, bytes - total, &read, nullptr) ||
        read == 0) {
      return false;
    }
    total += read;
  }
  return true;
}

bool WriteExact(HANDLE pipe, const void* source, DWORD bytes) {
  const auto* cursor = static_cast<const unsigned char*>(source);
  DWORD total = 0;
  while (total < bytes) {
    DWORD written = 0;
    if (!WriteFile(pipe, cursor + total, bytes - total, &written, nullptr) ||
        written == 0) {
      return false;
    }
    total += written;
  }
  return true;
}

bool ReadAcknowledgmentWithTimeout(HANDLE pipe, uint8_t* acknowledgment) {
  if (acknowledgment == nullptr) return false;
  const ULONGLONG deadline =
      GetTickCount64() + kActivationConnectTimeoutMilliseconds;
  while (GetTickCount64() < deadline) {
    DWORD available = 0;
    if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) {
      return false;
    }
    if (available >= sizeof(*acknowledgment)) {
      return ReadExact(pipe, acknowledgment, sizeof(*acknowledgment));
    }
    Sleep(10);
  }
  return false;
}

std::wstring CurrentUserSid() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return L"";
  DWORD length = 0;
  if (GetTokenInformation(token, TokenUser, nullptr, 0, &length) ||
      GetLastError() != ERROR_INSUFFICIENT_BUFFER || length == 0) {
    CloseHandle(token);
    return L"";
  }
  std::vector<unsigned char> buffer(length, 0);
  if (!GetTokenInformation(token, TokenUser, buffer.data(), length, &length)) {
    CloseHandle(token);
    return L"";
  }
  CloseHandle(token);
  const auto* user = reinterpret_cast<const TOKEN_USER*>(buffer.data());
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(user->User.Sid, &sid)) return L"";
  std::wstring value(sid);
  LocalFree(sid);
  return value;
}

BusyMaxSingleInstanceNativeHooks DefaultHooks() {
  BusyMaxSingleInstanceNativeHooks hooks;
  hooks.current_user_sid = CurrentUserSid;
  hooks.create_mutex = [](const wchar_t* name) {
    return CreateMutexW(nullptr, FALSE, name);
  };
  hooks.last_error = [] { return GetLastError(); };
  hooks.create_pipe = [](const wchar_t* name, SECURITY_ATTRIBUTES* attributes) {
    return CreateNamedPipeW(
        name, PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
            PIPE_REJECT_REMOTE_CLIENTS,
        1, sizeof(uint8_t), kMaximumActivationBytes + sizeof(uint32_t), 5000,
        attributes);
  };
  hooks.close_handle = [](HANDLE handle) { CloseHandle(handle); };
  return hooks;
}

std::string EscapeJson(const std::string& value) {
  std::string result;
  result.reserve(value.size() + 8);
  for (const unsigned char character : value) {
    switch (character) {
      case '\\':
        result += "\\\\";
        break;
      case '"':
        result += "\\\"";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      case '\t':
        result += "\\t";
        break;
      default:
        if (character < 0x20) return "";
        result.push_back(static_cast<char>(character));
    }
  }
  return result;
}

bool EndsWithIcs(const std::string& value) {
  if (value.size() < 4) return false;
  std::string suffix = value.substr(value.size() - 4);
  std::transform(suffix.begin(), suffix.end(), suffix.begin(),
                 [](unsigned char character) {
                   return static_cast<char>(std::tolower(character));
                 });
  return suffix == ".ics";
}

bool IsValidIcsPath(const std::string& value) {
  if (!EndsWithIcs(value) || value.size() > 32767 || value.empty()) {
    return false;
  }
  for (const unsigned char character : value) {
    if (character < 0x20 || character == '"' || character == '*' ||
        character == '<' || character == '>' || character == '|') {
      return false;
    }
  }
  const size_t colon = value.find(':');
  if (colon == std::string::npos) return true;
  const bool drive_path =
      colon == 1 && std::isalpha(static_cast<unsigned char>(value[0]));
  const bool extended_drive_path =
      colon == 5 && value.compare(0, 4, R"(\\?\)") == 0 &&
      std::isalpha(static_cast<unsigned char>(value[4]));
  return drive_path || extended_drive_path;
}

bool StartsWithWebcal(const std::string& value) {
  if (value.size() < 9) return false;
  std::string scheme = value.substr(0, 9);
  std::transform(scheme.begin(), scheme.end(), scheme.begin(),
                 [](unsigned char character) {
                   return static_cast<char>(std::tolower(character));
                 });
  return scheme == "webcal://";
}

bool IsValidWebcalUri(const std::string& value) {
  if (!StartsWithWebcal(value) || value.size() > 8192 ||
      value.find('#') != std::string::npos ||
      value.find('\\') != std::string::npos) {
    return false;
  }
  for (size_t index = 0; index < value.size(); ++index) {
    const unsigned char character = value[index];
    if (character <= 0x20 || character == 0x7f) return false;
    if (character == '%') {
      if (index + 2 >= value.size() ||
          !std::isxdigit(static_cast<unsigned char>(value[index + 1])) ||
          !std::isxdigit(static_cast<unsigned char>(value[index + 2]))) {
        return false;
      }
      index += 2;
    }
  }
  constexpr size_t kSchemeLength = 9;
  const size_t authority_end = value.find_first_of("/?", kSchemeLength);
  const std::string authority = value.substr(
      kSchemeLength, authority_end == std::string::npos
                         ? std::string::npos
                         : authority_end - kSchemeLength);
  return !authority.empty() && authority.find('@') == std::string::npos &&
         authority.find('\\') == std::string::npos;
}

bool ValidUtf8(const std::string& value) {
  if (value.empty()) return false;
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                             static_cast<int>(value.size()), nullptr, 0) > 0;
}

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
  return ValidUtf8(*decoded) && decoded->find('\0') == std::string::npos;
}

bool DecodeValueActivation(const std::string& activation,
                           const std::string& prefix,
                           std::string* decoded) {
  constexpr char kSuffix[] = "\"}";
  if (activation.size() < prefix.size() + 2 ||
      activation.compare(0, prefix.size(), prefix) != 0 ||
      activation.compare(activation.size() - 2, 2, kSuffix) != 0) {
    return false;
  }
  return DecodeJsonString(
      activation.substr(prefix.size(), activation.size() - prefix.size() - 2),
      decoded);
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
  while (cursor < activation.size() && activation[cursor] != '}') {
    std::string key;
    std::string value;
    if (!ParseJsonString(activation, &cursor, &key) ||
        cursor >= activation.size() || activation[cursor++] != ':' ||
        !ParseJsonString(activation, &cursor, &value) || value.empty() ||
        value.size() > 2048 ||
        (key != "notificationScheduleId" && key != "itemKind" &&
         key != "accountId" && key != "sourceId" && key != "itemId") ||
        !keys.insert(key).second) {
      return false;
    }
    if (cursor < activation.size() && activation[cursor] == ',') {
      ++cursor;
      if (cursor >= activation.size() || activation[cursor] == '}') {
        return false;
      }
    } else {
      break;
    }
  }
  return keys.find("notificationScheduleId") != keys.end() &&
         cursor + 2 == activation.size() && activation[cursor] == '}' &&
         activation[cursor + 1] == '}';
}

}  // namespace

BusyMaxSingleInstanceNativeHooks DefaultBusyMaxSingleInstanceNativeHooks() {
  return DefaultHooks();
}

BusyMaxSingleInstance::BusyMaxSingleInstance()
    : BusyMaxSingleInstance(DefaultBusyMaxSingleInstanceNativeHooks()) {}

BusyMaxSingleInstance::BusyMaxSingleInstance(
    BusyMaxSingleInstanceNativeHooks hooks)
    : hooks_(std::move(hooks)) {
  if (!hooks_.current_user_sid || !hooks_.create_mutex ||
      !hooks_.last_error || !hooks_.create_pipe || !hooks_.close_handle) {
    initialization_error_ = "single-instance native hooks are incomplete";
    return;
  }
  user_sid_ = hooks_.current_user_sid();
  if (user_sid_.empty()) {
    initialization_error_ = "current-user SID lookup failed";
    return;
  }
  pipe_name_ = std::wstring(kPipePrefix) + user_sid_;
  const std::wstring mutex_name = std::wstring(kMutexPrefix) + user_sid_;
  mutex_ = hooks_.create_mutex(mutex_name.c_str());
  const DWORD mutex_error = hooks_.last_error();
  if (mutex_ == nullptr) {
    initialization_error_ = "per-user mutex creation failed";
    return;
  }
  state_ = mutex_error == ERROR_ALREADY_EXISTS
               ? BusyMaxInstanceState::kSecondary
               : BusyMaxInstanceState::kPrimary;
}

BusyMaxSingleInstance::~BusyMaxSingleInstance() {
  Stop();
  if (mutex_ != nullptr) hooks_.close_handle(mutex_);
}

BusyMaxInstanceState BusyMaxSingleInstance::state() const { return state_; }

bool BusyMaxSingleInstance::IsPrimary() const {
  return state_ == BusyMaxInstanceState::kPrimary;
}

const std::string& BusyMaxSingleInstance::initialization_error() const {
  return initialization_error_;
}

bool BusyMaxSingleInstance::ForwardActivation(
    const std::string& activation) const {
  if (state_ != BusyMaxInstanceState::kSecondary ||
      !IsValidBusyMaxActivation(activation)) {
    return false;
  }
  HANDLE pipe = ConnectToActivationPipe(pipe_name_);
  if (pipe == INVALID_HANDLE_VALUE) return false;
  ULONG server_process_id = 0;
  if (GetNamedPipeServerProcessId(pipe, &server_process_id)) {
    AllowSetForegroundWindow(server_process_id);
  }
  const uint32_t length = static_cast<uint32_t>(activation.size());
  const bool written = WriteExact(pipe, &length, sizeof(length)) &&
                       WriteExact(pipe, activation.data(), length);
  uint8_t acknowledgment = 0;
  const bool acknowledged =
      written && ReadAcknowledgmentWithTimeout(pipe, &acknowledgment);
  hooks_.close_handle(pipe);
  return acknowledged && acknowledgment == 1;
}

bool BusyMaxSingleInstance::Start(
    std::function<void(std::string)> on_activation,
    std::function<void()> on_listener_failure) {
  if (state_ != BusyMaxInstanceState::kPrimary || listener_.joinable()) {
    return false;
  }
  stopping_ = false;
  {
    std::scoped_lock lock(listener_start_mutex_);
    listener_start_complete_ = false;
    listener_start_succeeded_ = false;
    listener_start_error_.clear();
  }
  on_activation_ = std::move(on_activation);
  on_listener_failure_ = std::move(on_listener_failure);
  try {
    listener_ = std::thread(&BusyMaxSingleInstance::Listen, this);
  } catch (const std::system_error&) {
    initialization_error_ = "named-pipe listener thread creation failed";
    state_ = BusyMaxInstanceState::kFatalInitializationFailure;
    return false;
  }
  std::unique_lock lock(listener_start_mutex_);
  const bool acknowledged = listener_start_condition_.wait_for(
      lock, std::chrono::seconds(5),
      [this] { return listener_start_complete_; });
  if (!acknowledged) {
    initialization_error_ = "named-pipe listener startup timed out";
    lock.unlock();
    Stop();
    state_ = BusyMaxInstanceState::kFatalInitializationFailure;
    return false;
  }
  if (!listener_start_succeeded_) {
    initialization_error_ = listener_start_error_;
    lock.unlock();
    if (listener_.joinable()) listener_.join();
    state_ = BusyMaxInstanceState::kFatalInitializationFailure;
    return false;
  }
  return true;
}

void BusyMaxSingleInstance::Stop() {
  if (!listener_.joinable()) return;
  stopping_ = true;
  HANDLE pipe = CreateFileW(pipe_name_.c_str(), GENERIC_READ | GENERIC_WRITE,
                            0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (pipe != INVALID_HANDLE_VALUE) hooks_.close_handle(pipe);
  CancelSynchronousIo(static_cast<HANDLE>(listener_.native_handle()));
  listener_.join();
}

HANDLE BusyMaxSingleInstance::CreateSecuredPipe(
    SECURITY_ATTRIBUTES* attributes) const {
  return hooks_.create_pipe(pipe_name_.c_str(), attributes);
}

void BusyMaxSingleInstance::CompleteListenerStartup(bool succeeded,
                                                    std::string error) {
  {
    std::scoped_lock lock(listener_start_mutex_);
    if (listener_start_complete_) return;
    listener_start_succeeded_ = succeeded;
    listener_start_error_ = std::move(error);
    listener_start_complete_ = true;
  }
  listener_start_condition_.notify_one();
}

void BusyMaxSingleInstance::Listen() {
  const std::wstring sddl = L"D:P(A;;GA;;;" + user_sid_ + L")";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) {
    CompleteListenerStartup(false,
                            "named-pipe security descriptor creation failed");
    return;
  }
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), descriptor,
                                 FALSE};
  HANDLE pipe = CreateSecuredPipe(&attributes);
  if (pipe == INVALID_HANDLE_VALUE) {
    LocalFree(descriptor);
    CompleteListenerStartup(false, "secured named-pipe creation failed");
    return;
  }
  CompleteListenerStartup(true, "");
  while (!stopping_) {
    const bool connected = ConnectNamedPipe(pipe, nullptr) ||
                           GetLastError() == ERROR_PIPE_CONNECTED;
    uint8_t acknowledgment = 0;
    if (connected && !stopping_) {
      uint32_t length = 0;
      if (ReadExact(pipe, &length, sizeof(length)) && length > 0 &&
          length <= kMaximumActivationBytes) {
        std::string message(length, '\0');
        if (ReadExact(pipe, message.data(), length) &&
            IsValidBusyMaxActivation(message)) {
          if (on_activation_) {
            on_activation_(std::move(message));
            acknowledgment = 1;
          }
        }
      }
      WriteExact(pipe, &acknowledgment, sizeof(acknowledgment));
      FlushFileBuffers(pipe);
    }
    DisconnectNamedPipe(pipe);
    hooks_.close_handle(pipe);
    pipe = INVALID_HANDLE_VALUE;
    if (!stopping_) {
      pipe = CreateSecuredPipe(&attributes);
      if (pipe == INVALID_HANDLE_VALUE) {
        MessageBoxW(nullptr,
                    L"BusyMax lost its secured activation channel. Close "
                    L"BusyMax before starting it again.",
                    L"BusyMax activation error", MB_OK | MB_ICONERROR);
        if (on_listener_failure_) on_listener_failure_();
        break;
      }
    }
  }
  if (pipe != INVALID_HANDLE_VALUE) hooks_.close_handle(pipe);
  LocalFree(descriptor);
}

std::string BuildBusyMaxActivation(
    const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    // The notification plugin is a local COM server. Keep its cold-start
    // process hidden until the validated callback tells Dart whether the
    // selected action actually requires visible UI.
    if (argument == "--start-minimized" ||
        argument == "----AppNotificationActivationServer") {
      return R"({"version":1,"kind":"startMinimized"})";
    }
  }
  for (const auto& argument : arguments) {
    if (IsValidIcsPath(argument)) {
      const auto escaped = EscapeJson(argument);
      if (!escaped.empty()) {
        return "{\"version\":1,\"kind\":\"icsFile\",\"value\":\"" +
               escaped + "\"}";
      }
    }
    if (IsValidWebcalUri(argument)) {
      const auto escaped = EscapeJson(argument);
      if (!escaped.empty()) {
        return "{\"version\":1,\"kind\":\"webCal\",\"value\":\"" +
               escaped + "\"}";
      }
    }
  }
  return R"({"version":1,"kind":"normalLaunch"})";
}

bool IsValidBusyMaxActivation(const std::string& activation) {
  if (activation.empty() || activation.size() > kMaximumActivationBytes ||
      !ValidUtf8(activation)) {
    return false;
  }
  if (activation == R"({"version":1,"kind":"normalLaunch"})" ||
      activation == R"({"version":1,"kind":"startMinimized"})") {
    return true;
  }
  std::string value;
  if (DecodeValueActivation(
          activation, R"({"version":1,"kind":"icsFile","value":")",
          &value)) {
    return IsValidIcsPath(value);
  }
  if (DecodeValueActivation(
          activation, R"({"version":1,"kind":"webCal","value":")",
          &value)) {
    return IsValidWebcalUri(value);
  }
  return IsValidNotificationActivation(activation);
}
