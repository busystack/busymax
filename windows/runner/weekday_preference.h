#ifndef BUSYMAX_WEEKDAY_PREFERENCE_H_
#define BUSYMAX_WEEKDAY_PREFERENCE_H_

#include <windows.h>

#include <optional>

// Reads the current user's regional override. Windows numbers Monday as zero.
inline std::optional<int> BusyMaxReadFirstWeekday(
    decltype(&GetLocaleInfoEx) read_locale = &GetLocaleInfoEx) {
  DWORD windows_weekday = 0;
  const int copied = read_locale(
      LOCALE_NAME_USER_DEFAULT,
      LOCALE_IFIRSTDAYOFWEEK | LOCALE_RETURN_NUMBER,
      reinterpret_cast<LPWSTR>(&windows_weekday),
      static_cast<int>(sizeof(windows_weekday) / sizeof(wchar_t)));
  if (copied == 0 || windows_weekday > 6) return std::nullopt;
  return static_cast<int>(windows_weekday) + 1;
}

#endif  // BUSYMAX_WEEKDAY_PREFERENCE_H_
