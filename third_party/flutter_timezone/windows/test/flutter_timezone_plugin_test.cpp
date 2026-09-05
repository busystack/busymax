#include "flutter_timezone_plugin.h"

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>

#include <algorithm>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace flutter_timezone {
namespace {

class FakeTimezoneApi final : public TimezoneNativeApi {
 public:
  DWORD query_result = TIME_ZONE_ID_STANDARD;
  int geo_result = 3;
  int32_t mapping_result = 17;
  UErrorCode mapping_status = U_ZERO_ERROR;
  UErrorCode open_status = U_ZERO_ERROR;
  UErrorCode count_status = U_ZERO_ERROR;
  UErrorCode next_status = U_ZERO_ERROR;
  int32_t count_result = 2;
  bool return_enumeration = true;
  int close_count = 0;
  size_t next_index = 0;
  std::wstring windows_id = L"Pacific Standard Time";
  std::wstring mapped_id = L"America/Vancouver";
  std::vector<std::string> enumerated = {"Etc/UTC", "America/Vancouver"};

  DWORD GetDynamicTimeZoneInformation(
      DYNAMIC_TIME_ZONE_INFORMATION* information) override {
    if (information != nullptr && query_result != TIME_ZONE_ID_INVALID) {
      wcsncpy_s(information->TimeZoneKeyName,
                _countof(information->TimeZoneKeyName), windows_id.c_str(),
                _TRUNCATE);
    }
    return query_result;
  }

  int GetUserDefaultGeoName(wchar_t* buffer, int capacity) override {
    if (geo_result > 0 && buffer != nullptr && capacity >= geo_result) {
      buffer[0] = L'C';
      buffer[1] = L'A';
      buffer[2] = L'\0';
    }
    return geo_result;
  }

  int32_t GetTimeZoneIdForWindowsId(const UChar*,
                                    int32_t,
                                    const char*,
                                    UChar* result,
                                    int32_t result_capacity,
                                    UErrorCode* status) override {
    *status = mapping_status;
    if (mapping_result > 0 && U_SUCCESS(*status) && result != nullptr &&
        result_capacity > mapping_result) {
      std::copy_n(mapped_id.data(), mapping_result, result);
    }
    return mapping_result;
  }

  UEnumeration* OpenTimeZoneIdEnumeration(UErrorCode* status) override {
    *status = open_status;
    return return_enumeration ? reinterpret_cast<UEnumeration*>(this) : nullptr;
  }

  int32_t EnumerationCount(UEnumeration*, UErrorCode* status) override {
    *status = count_status;
    return count_result;
  }

  const char* EnumerationNext(UEnumeration*,
                              int32_t* result_length,
                              UErrorCode* status) override {
    *status = next_status;
    if (U_FAILURE(*status) || next_index >= enumerated.size()) {
      *result_length = 0;
      return nullptr;
    }
    const std::string& current = enumerated[next_index++];
    *result_length = static_cast<int32_t>(current.size());
    return current.data();
  }

  void CloseEnumeration(UEnumeration*) override { ++close_count; }
};

struct CompletionCounts {
  int success = 0;
  int error = 0;
  int not_implemented = 0;

  int total() const { return success + error + not_implemented; }
};

CompletionCounts Invoke(FlutterTimezonePlugin& plugin,
                        const std::string& method) {
  CompletionCounts counts{};
  flutter::MethodCall<flutter::EncodableValue> call(method, nullptr);
  auto result = std::make_unique<
      flutter::MethodResultFunctions<flutter::EncodableValue>>(
      [&counts](const flutter::EncodableValue*) { ++counts.success; },
      [&counts](const std::string&, const std::string&,
                const flutter::EncodableValue*) { ++counts.error; },
      [&counts]() { ++counts.not_implemented; });
  plugin.HandleMethodCall(call, std::move(result));
  return counts;
}

TEST(FlutterTimezonePluginTest, MapsWindowsTimezoneToIana) {
  FakeTimezoneApi api;
  const auto result = ResolveLocalTimezone(api);
  EXPECT_TRUE(result.succeeded);
  EXPECT_EQ(result.value, "America/Vancouver");
}

TEST(FlutterTimezonePluginTest, RejectsUnavailableGeographicalInformation) {
  FakeTimezoneApi api;
  api.geo_result = 0;
  const auto result = ResolveLocalTimezone(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "windows-region-unavailable");
}

TEST(FlutterTimezonePluginTest, RejectsFailedWindowsTimezoneQuery) {
  FakeTimezoneApi api;
  api.query_result = TIME_ZONE_ID_INVALID;
  const auto result = ResolveLocalTimezone(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "windows-timezone-query-failed");
}

TEST(FlutterTimezonePluginTest, RejectsMissingOrZeroLengthIcuMapping) {
  FakeTimezoneApi api;
  api.mapping_result = 0;
  const auto result = ResolveLocalTimezone(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "icu-timezone-mapping-missing");
}

TEST(FlutterTimezonePluginTest, RejectsIcuErrorStatus) {
  FakeTimezoneApi api;
  api.mapping_status = U_INTERNAL_PROGRAM_ERROR;
  const auto result = ResolveLocalTimezone(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "icu-timezone-mapping-failed");
}

TEST(FlutterTimezonePluginTest, EnumerationOpenFailureDoesNotUseOrCloseHandle) {
  FakeTimezoneApi api;
  api.return_enumeration = false;
  api.open_status = U_MEMORY_ALLOCATION_ERROR;
  const auto result = EnumerateTimezones(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "icu-timezone-enumeration-open-failed");
  EXPECT_EQ(api.close_count, 0);
}

TEST(FlutterTimezonePluginTest, EnumerationOpenErrorClosesReturnedHandle) {
  FakeTimezoneApi api;
  api.open_status = U_INTERNAL_PROGRAM_ERROR;
  const auto result = EnumerateTimezones(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "icu-timezone-enumeration-open-failed");
  EXPECT_EQ(api.close_count, 1);
}

TEST(FlutterTimezonePluginTest, EnumerationReadFailureClosesHandleExactlyOnce) {
  FakeTimezoneApi api;
  api.next_status = U_INTERNAL_PROGRAM_ERROR;
  const auto result = EnumerateTimezones(api);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "icu-timezone-enumeration-read-failed");
  EXPECT_EQ(api.close_count, 1);
}

TEST(FlutterTimezonePluginTest, EveryMethodPathCompletesExactlyOnce) {
  FakeTimezoneApi success_api;
  FlutterTimezonePlugin success_plugin(&success_api);
  EXPECT_EQ(Invoke(success_plugin, kGetLocalTimezone).total(), 1);
  EXPECT_EQ(Invoke(success_plugin, kGetAvailableTimezones).total(), 1);

  FakeTimezoneApi failure_api;
  failure_api.mapping_status = U_INTERNAL_PROGRAM_ERROR;
  failure_api.open_status = U_INTERNAL_PROGRAM_ERROR;
  FlutterTimezonePlugin failure_plugin(&failure_api);
  const CompletionCounts local = Invoke(failure_plugin, kGetLocalTimezone);
  const CompletionCounts available =
      Invoke(failure_plugin, kGetAvailableTimezones);
  EXPECT_EQ(local.total(), 1);
  EXPECT_EQ(local.error, 1);
  EXPECT_EQ(available.total(), 1);
  EXPECT_EQ(available.error, 1);

  const CompletionCounts unknown = Invoke(success_plugin, "unknown");
  EXPECT_EQ(unknown.total(), 1);
  EXPECT_EQ(unknown.not_implemented, 1);
}

}  // namespace
}  // namespace flutter_timezone
