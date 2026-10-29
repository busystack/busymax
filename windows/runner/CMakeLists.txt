cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "single_instance.cpp"
  "notification_activation.cpp"
  "utils.cpp"
  "windows_startup_task.cpp"
  "windows_tray_channel.cpp"
  "tray_native_api.cpp"
  "windows_timezone_channel.cpp"
  "timezone_native_api.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# The pinned Flutter Windows toolchain targets C++17. C++/WinRT therefore uses
# the legacy coroutine header, which current MSVC toolsets require consumers to
# acknowledge.
target_compile_definitions(${BINARY_NAME} PRIVATE
  "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "advapi32.lib" "windowsapp.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib" "icu.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Built and executed explicitly by tool/windows/run_native_tests.ps1. Keeping
# it out of the default target prevents test code from entering the package.
add_executable(busymax_runner_native_test EXCLUDE_FROM_ALL
  "tests/single_instance_test.cpp"
  "single_instance.cpp"
  "notification_activation.cpp"
)
apply_standard_settings(busymax_runner_native_test)
target_compile_definitions(busymax_runner_native_test PRIVATE "NOMINMAX")
target_link_libraries(busymax_runner_native_test PRIVATE
  "advapi32.lib" "user32.lib")
add_test(NAME busymax_runner_native_test COMMAND busymax_runner_native_test)

add_executable(busymax_notification_activation_test EXCLUDE_FROM_ALL
  "tests/notification_activation_test.cpp"
  "notification_activation.cpp"
)
apply_standard_settings(busymax_notification_activation_test)
add_test(NAME busymax_notification_activation_test
  COMMAND busymax_notification_activation_test)

add_executable(busymax_short_time_pattern_test EXCLUDE_FROM_ALL
  "tests/short_time_pattern_test.cpp"
)
apply_standard_settings(busymax_short_time_pattern_test)
add_test(NAME busymax_short_time_pattern_test
  COMMAND busymax_short_time_pattern_test)

# These are BusyMax's OS behavior tests, formerly stored alongside modified
# plugins. They compile only application adapters, with official Google Test.
option(BUSYMAX_NATIVE_OS_TESTS "Build BusyMax Windows OS adapter regressions" OFF)
if(BUSYMAX_NATIVE_OS_TESTS)
  include(FetchContent)
  FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.18.0.zip
    URL_HASH SHA256=63b9c77751a5b8f492486005f67533fdc58682b67476fcb91650be5958d5195a)
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  add_executable(busymax_tray_native_test EXCLUDE_FROM_ALL
    "tests/tray_native_api_test.cpp" "tray_native_api.cpp")
  apply_standard_settings(busymax_tray_native_test)
  target_include_directories(busymax_tray_native_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(busymax_tray_native_test PRIVATE gtest_main "shell32.lib" "user32.lib")
  add_executable(busymax_timezone_native_test EXCLUDE_FROM_ALL
    "tests/timezone_native_api_test.cpp" "timezone_native_api.cpp"
    "windows_timezone_channel.cpp")
  apply_standard_settings(busymax_timezone_native_test)
  target_include_directories(busymax_timezone_native_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(busymax_timezone_native_test PRIVATE
    gtest_main flutter_wrapper_app "icu.lib")
  add_custom_command(TARGET busymax_timezone_native_test POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:busymax_timezone_native_test>)
  include(GoogleTest)
  gtest_discover_tests(busymax_tray_native_test)
  gtest_discover_tests(busymax_timezone_native_test)
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
