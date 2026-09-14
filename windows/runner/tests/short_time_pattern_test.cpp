#include "../short_time_pattern.h"

#include <cstdlib>
#include <iostream>

int main() {
  struct Example {
    const wchar_t* pattern;
    std::optional<bool> expected;
  };
  const Example examples[] = {
      {L"HH:mm", true},
      {L"H:mm", true},
      {L"h:mm tt", false},
      {L"hh:mm tt", false},
      {L"HH:mm;h:mm tt", true},
      {L"h:mm tt;HH:mm", false},
      {L"'h' HH:mm", true},
      {L"'H' h:mm tt", false},
      {L"'h; o''clock' HH:mm;h:mm tt", true},
      {L"'H; o''clock' h:mm tt;HH:mm", false},
      {L"''HH:mm", true},
      {L"''h:mm tt", false},
      {L"'h' mm;HH:mm", std::nullopt},
      {L"'HH:mm'", std::nullopt},
      {L"HH:mm 'unfinished", std::nullopt},
      {L"h H:mm", std::nullopt},
      {L";HH:mm", std::nullopt},
      {L"", std::nullopt},
  };
  for (const auto& example : examples) {
    if (BusyMaxShortTimeUses24Hours(example.pattern) != example.expected) {
      std::wcerr << L"Unexpected clock for pattern: " << example.pattern << '\n';
      return EXIT_FAILURE;
    }
  }
  std::cout << "Windows short-time pattern tests passed.\n";
  return EXIT_SUCCESS;
}
