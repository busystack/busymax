#include "registration_reader.h"
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#else
#include <cerrno>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#endif
namespace {
using Clock = std::chrono::steady_clock;
struct Request {
  std::atomic<int> references{2};
  std::atomic<bool> cancelled{false};
  std::string path;
  size_t maximum;
  Clock::time_point deadline;
  std::vector<uint8_t> bytes;
  int stopped() const {
    if (cancelled.load()) return 4;
    return Clock::now() >= deadline ? 5 : 0;
  }
};
#ifdef BUSYMAX_READER_TESTING
void (*test_hook)(int) = nullptr;
void hook(int phase) { if (test_hook) test_hook(phase); }
#else
void hook(int) {}
#endif
#ifdef _WIN32
struct Handle {
  HANDLE value;
  ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
int read_file(Request& request) {
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      request.path.c_str(), -1, nullptr, 0);
  if (!count) return 1;
  std::vector<wchar_t> path(static_cast<size_t>(count));
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      request.path.c_str(), -1, path.data(), count)) return 1;
  hook(0);
  if (int stopped = request.stopped()) return stopped;
  // Open reparse points themselves; never follow the selected final component.
  // UNC and device paths are also rejected by the Dart local-path policy.
  Handle file{CreateFileW(path.data(), GENERIC_READ,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS |
      FILE_FLAG_OVERLAPPED, nullptr)};
  if (file.value == INVALID_HANDLE_VALUE) return 1;
  BY_HANDLE_FILE_INFORMATION information{};
  if (GetFileType(file.value) != FILE_TYPE_DISK ||
      !GetFileInformationByHandle(file.value, &information) ||
      (information.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY |
                                      FILE_ATTRIBUTE_REPARSE_POINT))) return 2;
  if ((static_cast<uint64_t>(information.nFileSizeHigh) << 32 |
       information.nFileSizeLow) > request.maximum) return 3;
  hook(1);
  Handle event{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
  if (!event.value || event.value == INVALID_HANDLE_VALUE) return 1;
  for (;;) {
    if (int stopped = request.stopped()) return stopped;
    uint8_t chunk[4096];
    OVERLAPPED operation{};
    operation.hEvent = event.value;
    const uint64_t offset = request.bytes.size();
    operation.Offset = static_cast<DWORD>(offset);
    operation.OffsetHigh = static_cast<DWORD>(offset >> 32);
    ResetEvent(event.value);
    DWORD read = 0;
    BOOL done = ReadFile(file.value, chunk, static_cast<DWORD>(sizeof(chunk)),
                         &read, &operation);
    if (!done && GetLastError() == ERROR_IO_PENDING) {
      while (WaitForSingleObject(event.value, 20) == WAIT_TIMEOUT) {
        if (int stopped = request.stopped()) {
          CancelIoEx(file.value, &operation);
          // OVERLAPPED and buffer must remain alive until cancellation completes.
          GetOverlappedResult(file.value, &operation, &read, TRUE);
          return stopped;
        }
      }
      done = GetOverlappedResult(file.value, &operation, &read, FALSE);
    }
    if (!done && GetLastError() == ERROR_HANDLE_EOF) return 0;
    if (!done) return 1;
    if (!read) return 0;
    if (request.bytes.size() + read > request.maximum) return 3;
    request.bytes.insert(request.bytes.end(), chunk, chunk + read);
    hook(2);
  }
}
#else
struct Descriptor { int value; ~Descriptor() { if (value >= 0) close(value); } };
int read_file(Request& request) {
  hook(0);
  if (int stopped = request.stopped()) return stopped;
  // NONBLOCK prevents substituted FIFOs/devices blocking open before fstat.
  Descriptor file{open(request.path.c_str(), O_RDONLY | O_NOFOLLOW |
                      O_NONBLOCK | O_CLOEXEC)};
  if (file.value < 0) return errno == ELOOP ? 2 : 1;
  struct stat information{};
  if (fstat(file.value, &information) != 0) return 1;
  if (!S_ISREG(information.st_mode)) return 2;
  if (information.st_size < 0 ||
      static_cast<uint64_t>(information.st_size) > request.maximum) return 3;
  hook(1);
  for (;;) {
    if (int stopped = request.stopped()) return stopped;
    uint8_t chunk[4096];
    const ssize_t count = read(file.value, chunk, sizeof(chunk));
    if (count < 0) { if (errno == EINTR) continue; return 1; }
    if (!count) return 0;
    const auto size = static_cast<size_t>(count);
    if (request.bytes.size() + size > request.maximum) return 3;
    request.bytes.insert(request.bytes.end(), chunk, chunk + size);
    hook(2);
  }
}
#endif
}
extern "C" {
void* busymax_reader_create(const char* path, size_t maximum, int64_t milliseconds) {
  try {
    return new Request{{2}, {false}, std::string(path), maximum,
      Clock::now() + std::chrono::milliseconds(milliseconds), {}};
  } catch (...) { return nullptr; }
}
void busymax_reader_cancel(void* value) {
  static_cast<Request*>(value)->cancelled.store(true);
}
void busymax_reader_release(void* value) {
  auto* request = static_cast<Request*>(value);
  if (request->references.fetch_sub(1) == 1) delete request;
}
int busymax_reader_run(void* value) {
  auto& request = *static_cast<Request*>(value);
  try { return read_file(request); } catch (...) { return 1; }
}
const uint8_t* busymax_reader_bytes(void* value) {
  return static_cast<Request*>(value)->bytes.data();
}
size_t busymax_reader_size(void* value) {
  return static_cast<Request*>(value)->bytes.size();
}
void* busymax_reader_allocate(size_t count) { return malloc(count); }
void busymax_reader_free(void* value) { free(value); }
}
#ifdef BUSYMAX_READER_TESTING
void busymax_reader_test_hook(void (*value)(int)) { test_hook = value; }
#endif
