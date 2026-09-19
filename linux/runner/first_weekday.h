#ifndef BUSYMAX_FIRST_WEEKDAY_H_
#define BUSYMAX_FIRST_WEEKDAY_H_

#include <langinfo.h>

#include <cstdint>
#include <optional>

// Reads the effective LC_TIME convention using glibc's private locale items.
//
// _NL_TIME_FIRST_WEEKDAY is a one-byte offset from the date encoded by
// _NL_TIME_WEEK_1STDAY. For the numeric item, glibc returns the word in the
// pointer value itself; the returned address must not be dereferenced.
inline std::optional<int> BusyMaxReadFirstWeekday() {
#if defined(__GLIBC__) && defined(__USE_GNU)
  const char* relative_bytes = nl_langinfo(_NL_TIME_FIRST_WEEKDAY);
  if (relative_bytes == nullptr) return std::nullopt;

  const unsigned relative_weekday =
      static_cast<unsigned char>(relative_bytes[0]);
  if (relative_weekday < 1 || relative_weekday > 7) return std::nullopt;

  const std::uintptr_t origin_word = reinterpret_cast<std::uintptr_t>(
      nl_langinfo(_NL_TIME_WEEK_1STDAY));
  int origin_weekday = 0;
  if (origin_word == 19971130U) {
    origin_weekday = 7;  // Sunday in Dart numbering.
  } else if (origin_word == 19971201U) {
    origin_weekday = 1;  // Monday in Dart numbering.
  } else {
    return std::nullopt;
  }

  return ((origin_weekday + static_cast<int>(relative_weekday) - 2) % 7) + 1;
#else
  return std::nullopt;
#endif
}

#endif  // BUSYMAX_FIRST_WEEKDAY_H_
