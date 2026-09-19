#ifndef BUSYMAX_FIRST_WEEKDAY_H_
#define BUSYMAX_FIRST_WEEKDAY_H_

#include <langinfo.h>

#include <cstdint>
#include <cstring>
#include <optional>

// Reads the effective LC_TIME convention using glibc's private locale items.
//
// _NL_TIME_FIRST_WEEKDAY is a one-byte offset from the date encoded by
// _NL_TIME_WEEK_1STDAY. glibc stores the numeric item in a union whose pointer
// member is returned by nl_langinfo, while GTK reads the union's word member.
// Decode that word from the local pointer object's representation; the address
// contained in the returned pointer is opaque and must not be dereferenced.
namespace busymax_internal {

inline std::optional<int> DecodeFirstWeekday(unsigned relative_weekday,
                                             const char* raw_origin) {
  static_assert(sizeof(raw_origin) >= sizeof(std::uint32_t),
                "locale pointer representation must contain the origin word");

  if (relative_weekday < 1 || relative_weekday > 7) return std::nullopt;

  std::uint32_t origin_word = 0;
  std::memcpy(&origin_word, &raw_origin, sizeof(origin_word));
  int origin_weekday = 0;
  if (origin_word == 19971130U) {
    origin_weekday = 7;  // Sunday in Dart numbering.
  } else if (origin_word == 19971201U) {
    origin_weekday = 1;  // Monday in Dart numbering.
  } else {
    return std::nullopt;
  }

  return ((origin_weekday + static_cast<int>(relative_weekday) - 2) % 7) + 1;
}

}  // namespace busymax_internal

inline std::optional<int> BusyMaxReadFirstWeekday() {
#if defined(__GLIBC__) && defined(__USE_GNU)
  const char* relative_bytes = nl_langinfo(_NL_TIME_FIRST_WEEKDAY);
  if (relative_bytes == nullptr) return std::nullopt;

  const unsigned relative_weekday =
      static_cast<unsigned char>(relative_bytes[0]);
  const char* raw_origin = nl_langinfo(_NL_TIME_WEEK_1STDAY);
  return busymax_internal::DecodeFirstWeekday(relative_weekday, raw_origin);
#else
  return std::nullopt;
#endif
}

#endif  // BUSYMAX_FIRST_WEEKDAY_H_
