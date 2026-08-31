cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "tray_manager")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "tray_manager_plugin")

add_library(${PLUGIN_NAME} SHARED
  "tray_manager_plugin.cpp"
  "tray_native_api.cpp"
  "tray_native_api.h"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_definitions(${PLUGIN_NAME} PRIVATE _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter flutter_wrapper_plugin "shell32.lib" "user32.lib")

# List of absolute paths to libraries that should be bundled with the plugin
set(tray_manager_bundled_libraries
  ""
  PARENT_SCOPE
)

if (${include_${PROJECT_NAME}_tests})
  set(TEST_RUNNER "${PROJECT_NAME}_test")
  enable_testing()
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/release-1.11.0.zip
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
  FetchContent_MakeAvailable(googletest)
  add_executable(${TEST_RUNNER}
    "test/tray_native_api_test.cpp"
    "tray_native_api.cpp"
    "tray_native_api.h"
  )
  apply_standard_settings(${TEST_RUNNER})
  target_include_directories(${TEST_RUNNER} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
  )
  target_link_libraries(${TEST_RUNNER} PRIVATE
    gtest_main gmock "shell32.lib" "user32.lib")
  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
