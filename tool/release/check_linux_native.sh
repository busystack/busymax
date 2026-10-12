#!/usr/bin/env bash
set -euo pipefail
native_gtk_config="${BUSYMAX_GTK_CONFIG:-build/linux/native-tests/gtk-config}"
mkdir -p "$native_gtk_config/gtk-3.0"
printf '[Settings]\ngtk-icon-theme-name=Yaru\n' > "$native_gtk_config/gtk-3.0/settings.ini"
mkdir -p build/linux/native-tests
g++ -std=c++17 -Wall -Wextra -Werror \
  windows/runner/tests/short_time_pattern_test.cpp \
  -o build/linux/native-tests/short_time_pattern_test
build/linux/native-tests/short_time_pattern_test
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/first_weekday_test.cc \
  -o build/linux/native-tests/first_weekday_test
build/linux/native-tests/first_weekday_test
mkdir -p build/linux/native-tests/weekday-schemas
glib-compile-schemas --strict \
  --targetdir=build/linux/native-tests/weekday-schemas \
  linux/runner/tests/schemas
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/first_weekday_preference_test.cc \
  linux/runner/first_weekday_preference.cc \
  -o build/linux/native-tests/first_weekday_preference_test \
  $(pkg-config --cflags --libs gio-2.0)
build/linux/native-tests/first_weekday_preference_test \
  build/linux/native-tests/weekday-schemas
LC_ALL=C.UTF-8 MALLOC_PERTURB_=165 \
  build/linux/native-tests/first_weekday_test
g++ -std=c++17 -Wall -Wextra -Werror \
  -fsanitize=address -fno-omit-frame-pointer \
  linux/runner/tests/first_weekday_test.cc \
  -o build/linux/native-tests/first_weekday_test_asan
ASAN_OPTIONS=detect_leaks=0 \
  build/linux/native-tests/first_weekday_test_asan
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/time_picker_test.cc \
  -o build/linux/native-tests/time_picker_test \
  $(pkg-config --cflags --libs gtk+-3.0)
xvfb-run -a build/linux/native-tests/time_picker_test
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/gtk_window_preferences_test.cc \
  linux/runner/gtk_window_preferences.cc \
  -o build/linux/native-tests/gtk_window_preferences_test \
  $(pkg-config --cflags --libs gtk+-3.0)
xvfb-run -a build/linux/native-tests/gtk_window_preferences_test
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/gtk_header_icons_test.cc \
  linux/runner/gtk_header_icons.cc \
  -o build/linux/native-tests/gtk_header_icons_test \
  $(pkg-config --cflags --libs gtk+-3.0)
XDG_CONFIG_HOME="${BUSYMAX_GTK_CONFIG:-build/linux/native-tests/gtk-config}" \
  xvfb-run -a sh -c 'build/linux/native-tests/gtk_header_icons_test'
g++ -std=c++17 -Wall -Wextra -Werror \
  linux/runner/tests/gtk_search_entry_theme_test.cc \
  linux/runner/gtk_search_entry_theme.cc \
  -o build/linux/native-tests/gtk_search_entry_theme_test \
  $(pkg-config --cflags --libs gtk+-3.0)
xvfb-run -a env GDK_BACKEND=x11 \
  build/linux/native-tests/gtk_search_entry_theme_test
