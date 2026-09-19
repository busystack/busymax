#include "../first_weekday.h"

#include <cassert>
#include <clocale>
#include <cstdio>
#include <cstdlib>
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

}  // namespace

int main() {
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
  return 0;
}
