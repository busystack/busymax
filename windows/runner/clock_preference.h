#ifndef BUSYMAX_CLOCK_PREFERENCE_H_
#define BUSYMAX_CLOCK_PREFERENCE_H_

#include <windows.h>
#include <cwchar>
#include <optional>

inline bool BusyMaxClockRefreshMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  return (message == WM_SETTINGCHANGE &&
          (lparam == 0 || _wcsicmp(reinterpret_cast<const wchar_t*>(lparam), L"intl") == 0)) ||
         (message == WM_ACTIVATEAPP && wparam != 0);
}

inline std::optional<bool> BusyMaxRead24HourClock() {
  wchar_t clock[2] = {};
  if (GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_ITIME, clock, 2) == 0) {
    return std::nullopt;
  }
  return clock[0] == L'1';
}
#endif
