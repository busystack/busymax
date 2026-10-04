#include "registration_reader.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#ifndef _WIN32
#include <sys/stat.h>
#endif
namespace fs = std::filesystem;
namespace {
fs::path selected, replacement;
int action = 0;
void require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
void write(const fs::path& path, const std::string& bytes) {
  std::ofstream stream(path, std::ios::binary | std::ios::trunc);
  stream << bytes;
}
void substitution(int phase) {
  if (action == 1 && phase == 0) {
    fs::remove(selected);
    fs::create_symlink(replacement, selected);
  } else if (action == 2 && phase == 1) {
    fs::rename(selected, selected.string() + ".opened");
    fs::rename(replacement, selected);
  } else if (action == 4 && phase == 0) {
    fs::remove(selected);
  } else if (action == 3 && phase == 1) {
    std::ofstream stream(selected, std::ios::binary | std::ios::app);
    stream << std::string(65536, 'g');
  }
}
int read(const fs::path& path, std::string* bytes = nullptr,
         bool cancel = false, int64_t timeout = 1000) {
  const std::string utf8 = path.u8string();
  void* request = busymax_reader_create(utf8.c_str(), 65536, timeout);
  require(request != nullptr, "create");
  if (cancel) busymax_reader_cancel(request);
  const int result = busymax_reader_run(request);
  if (bytes && result == 0) {
    bytes->assign(reinterpret_cast<const char*>(busymax_reader_bytes(request)),
                  busymax_reader_size(request));
  }
  busymax_reader_release(request);
  busymax_reader_release(request);
  return result;
}
}
int main() {
  const auto root = fs::temp_directory_path() / ("busymax-reader-" +
      std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
  fs::create_directory(root);
  try {
    selected = root / "selected.json";
    replacement = root / "replacement.json";
    write(selected, "original"); write(replacement, "replacement");
    require(read(root) == 2, "directory accepted");
    require(read(root / "missing") == 1, "missing accepted");
    require(read(selected, nullptr, true) == 4, "cancel ignored");
    require(read(selected, nullptr, false, 0) == 5, "deadline ignored");
    busymax_reader_test_hook(substitution);
    action = 1;
    require(read(selected) == 2, "substituted symlink accepted");
    fs::remove(selected); write(selected, "original");
    action = 2;
    std::string bytes;
    require(read(selected, &bytes) == 0 && bytes == "original",
            "pathname was reopened after validating handle");
    action = 4;
    require(read(selected) == 1, "disappeared object accepted"); action = 0;
    write(selected, "original");
    const auto hardlink = root / "hardlink.json";
    fs::create_hard_link(selected, hardlink);
    require(read(hardlink, &bytes) == 0 && bytes == "original", "regular hard link rejected");
#ifndef _WIN32
    fs::permissions(selected, fs::perms::none);
    require(read(selected) == 1, "permission failure ignored");
    fs::permissions(selected, fs::perms::owner_read | fs::perms::owner_write);
#endif
    write(selected, std::string(65536, 'b'));
    require(read(selected, &bytes) == 0 && bytes.size() == 65536, "boundary rejected");
    write(selected, std::string(65537, 'b'));
    require(read(selected) == 3, "oversize accepted");
    write(selected, "original"); action = 3;
    require(read(selected) == 3, "growth accepted"); action = 0;
#ifndef _WIN32
    fs::remove(selected);
    require(mkfifo(selected.c_str(), 0600) == 0, "mkfifo failed");
    require(read(selected) == 2, "FIFO accepted or blocked");
    require(read("/dev/null") == 2, "device accepted");
#else
    require(read("\\\\.\\NUL") == 2, "non-disk Windows handle accepted");
#endif
    fs::remove_all(root);
    std::cout << "Native handle-policy checks passed\n";
    return 0;
  } catch (const std::exception& error) {
    fs::remove_all(root);
    std::cerr << error.what() << '\n';
    return 1;
  }
}
