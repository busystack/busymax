#ifndef BUSYMAX_CLOCK_PREFERENCE_H_
#define BUSYMAX_CLOCK_PREFERENCE_H_

#include <windows.h>
#include <cwchar>
#include <optional>
#include <string>

#include "short_time_pattern.h"

inline bool BusyMaxClockRefreshMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  return (message == WM_SETTINGCHANGE &&
          (lparam == 0 || _wcsicmp(reinterpret_cast<const wchar_t*>(lparam), L"intl") == 0)) ||
         (message == WM_ACTIVATEAPP && wparam != 0);
}

inline std::optional<bool> BusyMaxRead24HourClock(
    decltype(&GetLocaleInfoEx) read_locale = &GetLocaleInfoEx) {
  // LOCALE_ITIME describes the long-time format, which can use a different
  // clock from the user's preferred short-time format. Keep user overrides.
  const int length = read_locale(LOCALE_NAME_USER_DEFAULT, LOCALE_SSHORTTIME,
                                nullptr, 0);
  if (length <= 1) return std::nullopt;
  std::wstring pattern(static_cast<std::size_t>(length), L'\0');
  const int copied = read_locale(LOCALE_NAME_USER_DEFAULT, LOCALE_SSHORTTIME,
                                pattern.data(), length);
  if (copied <= 1 || copied > length) return std::nullopt;
  return BusyMaxShortTimeUses24Hours(
      std::wstring_view(pattern.data(), static_cast<std::size_t>(copied - 1)));
}
#endif
