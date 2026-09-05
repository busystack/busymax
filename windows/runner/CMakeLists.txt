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
  "utils.cpp"
  "windows_startup_task.cpp"
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

# Flutter 3.44.4 targets C++17. C++/WinRT therefore uses the legacy coroutine
# header, which current MSVC toolsets require consumers to acknowledge.
target_compile_definitions(${BINARY_NAME} PRIVATE
  "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "advapi32.lib" "windowsapp.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Built and executed explicitly by tool/windows/run_native_tests.ps1. Keeping
# it out of the default target prevents test code from entering the package.
add_executable(busymax_runner_native_test EXCLUDE_FROM_ALL
  "tests/single_instance_test.cpp"
  "single_instance.cpp"
)
apply_standard_settings(busymax_runner_native_test)
target_compile_definitions(busymax_runner_native_test PRIVATE "NOMINMAX")
target_link_libraries(busymax_runner_native_test PRIVATE
  "advapi32.lib" "user32.lib")
add_test(NAME busymax_runner_native_test COMMAND busymax_runner_native_test)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
