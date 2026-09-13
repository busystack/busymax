cmake_minimum_required(VERSION 3.14)
project(busymax_activation_contract_tests LANGUAGES CXX)

# Build the runner's production notification validator independently of Flutter
# and Win32, so Dart forwarding tests can check the native contract on every host.
add_executable(busymax_notification_activation_test
  "notification_activation_test.cpp"
  "../notification_activation.cpp"
)
target_compile_features(busymax_notification_activation_test PRIVATE cxx_std_17)
if(MSVC)
  target_compile_options(busymax_notification_activation_test PRIVATE /W4 /WX)
else()
  target_compile_options(busymax_notification_activation_test PRIVATE
    -Wall -Wextra -Werror)
endif()
enable_testing()
add_test(NAME busymax_notification_activation_test
  COMMAND busymax_notification_activation_test)
