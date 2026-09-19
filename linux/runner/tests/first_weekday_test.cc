#include "../first_weekday.h"

#include <array>
#include <cassert>
#include <clocale>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {

void RequireLocale(const char* category_name, int category,
                   const char* locale_name) {
  if (std::setlocale(category, locale_name) == nullptr) {
    std::fprintf(stderr, "Required %s locale is unavailable: %s\n",
                 category_name, locale_name);
    std::abort();
  }
}

const char* SyntheticOrigin(std::uint32_t origin_word, unsigned char fill) {
  std::array<unsigned char, sizeof(const char*)> storage;
  storage.fill(fill);
  std::memcpy(storage.data(), &origin_word, sizeof(origin_word));

  const char* opaque = nullptr;
  std::memcpy(&opaque, storage.data(), sizeof(opaque));
  return opaque;
}

void TestSyntheticOrigin(std::uint32_t origin_word,
                         const std::array<int, 7>& expected) {
  for (unsigned relative_weekday = 1; relative_weekday <= 7;
       ++relative_weekday) {
    const auto zero_filled = busymax_internal::DecodeFirstWeekday(
        relative_weekday, SyntheticOrigin(origin_word, 0));
    const auto nonzero_filled = busymax_internal::DecodeFirstWeekday(
        relative_weekday, SyntheticOrigin(origin_word, 0xA5));
    assert(zero_filled == expected[relative_weekday - 1]);
    assert(nonzero_filled == zero_filled);
  }
}

}  // namespace

int main() {
  TestSyntheticOrigin(19971130U, {7, 1, 2, 3, 4, 5, 6});
  TestSyntheticOrigin(19971201U, {1, 2, 3, 4, 5, 6, 7});
  assert(!busymax_internal::DecodeFirstWeekday(
              0, SyntheticOrigin(19971130U, 0xA5))
              .has_value());
  assert(!busymax_internal::DecodeFirstWeekday(
              8, SyntheticOrigin(19971201U, 0xA5))
              .has_value());
  assert(!busymax_internal::DecodeFirstWeekday(
              1, SyntheticOrigin(20000101U, 0xA5))
              .has_value());

  // Execute the real glibc reader in the process's effective locale. This
  // catches both accidental preprocessing-out and invalid pointer decoding.
  assert(std::setlocale(LC_ALL, "") != nullptr);
  const auto effective = BusyMaxReadFirstWeekday();
  assert(effective.has_value());
  assert(*effective >= 1 && *effective <= 7);

  // The display language and time-format locale are independent. Keep
  // messages in US English while selecting the British LC_TIME convention.
  RequireLocale("LC_MESSAGES", LC_MESSAGES, "en_US.UTF-8");
  RequireLocale("LC_TIME", LC_TIME, "en_GB.UTF-8");
  assert(std::string(std::setlocale(LC_MESSAGES, nullptr)).find("en_US") == 0);
  assert(BusyMaxReadFirstWeekday() == 1);  // Monday.

  RequireLocale("LC_TIME", LC_TIME, "en_US.UTF-8");
  assert(BusyMaxReadFirstWeekday() == 7);  // Sunday.

  RequireLocale("LC_TIME", LC_TIME, "C.UTF-8");
  assert(BusyMaxReadFirstWeekday() == 7);  // Sunday.
  return 0;
}
