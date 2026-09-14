#ifndef BUSYMAX_SHORT_TIME_PATTERN_H_
#define BUSYMAX_SHORT_TIME_PATTERN_H_

#include <optional>
#include <string_view>

// LOCALE_SSHORTTIME can contain a list; only its first pattern is preferred.
// Windows format pictures quote literal text with apostrophes and escape an
// apostrophe by doubling it. Only an unquoted h/H is an hour token.
inline std::optional<bool> BusyMaxShortTimeUses24Hours(std::wstring_view pattern) {
  bool quoted = false;
  std::optional<bool> clock;
  for (std::size_t index = 0; index < pattern.size(); ++index) {
    const wchar_t token = pattern[index];
    if (token == L'\'') {
      if (index + 1 < pattern.size() && pattern[index + 1] == L'\'') {
        ++index;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted) {
      if (token == L';') break;
      if (token == L'h' || token == L'H') {
        const bool use24 = token == L'H';
        if (clock.has_value() && *clock != use24) return std::nullopt;
        clock = use24;
      }
    }
  }
  return quoted ? std::nullopt : clock;
}

#endif
