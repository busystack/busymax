#include "timezone_native_api.h"

#include <array>
#include <limits>
#include <utility>

namespace flutter_timezone {
namespace {

// GetUserDefaultGeoName requires space for at least 85 UTF-16 code units.
// GEO_NAME_LENGTH is not exposed by every supported Windows SDK header set,
// so keep the documented capacity local to this narrow Win32 adapter.
constexpr size_t kGeoNameCapacity = 85;

TimezoneOperationResult Failure(const char* code, const char* message) {
  TimezoneOperationResult result{};
  result.error_code = code;
  result.error_message = message;
  return result;
}

bool WideToUtf8(const wchar_t* value,
                int32_t length,
                std::string* converted) {
  if (value == nullptr || converted == nullptr || length <= 0) {
    return false;
  }
  const int required = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value,
                                            length, nullptr, 0, nullptr, nullptr);
  if (required <= 0) {
    return false;
  }
  converted->assign(static_cast<size_t>(required), '\0');
  return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, length,
                             converted->data(), required, nullptr, nullptr) ==
         required;
}

class EnumerationOwner {
 public:
  EnumerationOwner(TimezoneNativeApi& api, UEnumeration* value)
      : api_(api), value_(value) {}
  ~EnumerationOwner() {
    if (value_ != nullptr) {
      api_.CloseEnumeration(value_);
    }
  }
  UEnumeration* get() const { return value_; }

  EnumerationOwner(const EnumerationOwner&) = delete;
  EnumerationOwner& operator=(const EnumerationOwner&) = delete;

 private:
  TimezoneNativeApi& api_;
  UEnumeration* value_;
};

}  // namespace

DWORD WindowsTimezoneNativeApi::GetDynamicTimeZoneInformation(
    DYNAMIC_TIME_ZONE_INFORMATION* information) {
  return ::GetDynamicTimeZoneInformation(information);
}

int WindowsTimezoneNativeApi::GetUserDefaultGeoName(wchar_t* buffer,
                                                     int capacity) {
  return ::GetUserDefaultGeoName(buffer, capacity);
}

int32_t WindowsTimezoneNativeApi::GetTimeZoneIdForWindowsId(
    const UChar* windows_id,
    int32_t windows_id_length,
    const char* region,
    UChar* result,
    int32_t result_capacity,
    UErrorCode* status) {
  return ucal_getTimeZoneIDForWindowsID(windows_id, windows_id_length, region,
                                        result, result_capacity, status);
}

UEnumeration* WindowsTimezoneNativeApi::OpenTimeZoneIdEnumeration(
    UErrorCode* status) {
  return ucal_openTimeZoneIDEnumeration(UCAL_ZONE_TYPE_CANONICAL, nullptr,
                                        nullptr, status);
}

int32_t WindowsTimezoneNativeApi::EnumerationCount(
    UEnumeration* enumeration,
    UErrorCode* status) {
  return uenum_count(enumeration, status);
}

const char* WindowsTimezoneNativeApi::EnumerationNext(
    UEnumeration* enumeration,
    int32_t* result_length,
    UErrorCode* status) {
  return uenum_next(enumeration, result_length, status);
}

void WindowsTimezoneNativeApi::CloseEnumeration(UEnumeration* enumeration) {
  uenum_close(enumeration);
}

TimezoneOperationResult ResolveLocalTimezone(TimezoneNativeApi& api) {
  DYNAMIC_TIME_ZONE_INFORMATION information{};
  if (api.GetDynamicTimeZoneInformation(&information) ==
      TIME_ZONE_ID_INVALID) {
    return Failure("windows-timezone-query-failed",
                   "Windows could not provide its current time zone.");
  }

  const size_t key_length = wcsnlen_s(information.TimeZoneKeyName,
                                      _countof(information.TimeZoneKeyName));
  if (key_length == 0 ||
      key_length >= _countof(information.TimeZoneKeyName) ||
      key_length >
          static_cast<size_t>((std::numeric_limits<int32_t>::max)())) {
    return Failure("windows-timezone-key-invalid",
                   "Windows returned an invalid time-zone key.");
  }

  std::array<wchar_t, kGeoNameCapacity> geo_buffer{};
  const int geo_length = api.GetUserDefaultGeoName(
      geo_buffer.data(), static_cast<int>(geo_buffer.size()));
  if (geo_length <= 0 || geo_length > static_cast<int>(geo_buffer.size())) {
    return Failure("windows-region-unavailable",
                   "Windows could not provide the current geographic region.");
  }
  // The Win32 length includes the terminator. Never infer a length by reading
  // beyond what the API reported.
  const int explicit_geo_length =
      geo_buffer[static_cast<size_t>(geo_length - 1)] == L'\0'
          ? geo_length - 1
          : geo_length;
  if (explicit_geo_length <= 0) {
    return Failure("windows-region-empty",
                   "Windows returned an empty geographic region.");
  }
  std::string region;
  if (!WideToUtf8(geo_buffer.data(), explicit_geo_length, &region)) {
    return Failure("windows-region-encoding-failed",
                   "Windows returned an invalid geographic region.");
  }

  std::array<UChar, 256> mapped{};
  UErrorCode status = U_ZERO_ERROR;
  const int32_t mapped_length = api.GetTimeZoneIdForWindowsId(
      information.TimeZoneKeyName, static_cast<int32_t>(key_length),
      region.c_str(), mapped.data(), static_cast<int32_t>(mapped.size()),
      &status);
  if (U_FAILURE(status)) {
    return Failure("icu-timezone-mapping-failed",
                   "ICU could not map the Windows time zone.");
  }
  if (mapped_length <= 0) {
    return Failure("icu-timezone-mapping-missing",
                   "No IANA mapping exists for the Windows time zone.");
  }
  if (mapped_length >= static_cast<int32_t>(mapped.size())) {
    return Failure("icu-timezone-mapping-too-long",
                   "The mapped IANA time zone exceeded the safe limit.");
  }

  std::string identifier;
  if (!WideToUtf8(mapped.data(), mapped_length, &identifier)) {
    return Failure("icu-timezone-encoding-failed",
                   "ICU returned an invalid IANA time zone.");
  }
  TimezoneOperationResult result{};
  result.succeeded = true;
  result.value = std::move(identifier);
  return result;
}

TimezoneOperationResult EnumerateTimezones(TimezoneNativeApi& api) {
  UErrorCode status = U_ZERO_ERROR;
  UEnumeration* raw_enumeration = api.OpenTimeZoneIdEnumeration(&status);
  if (raw_enumeration == nullptr) {
    return Failure("icu-timezone-enumeration-open-failed",
                   "ICU could not open the time-zone catalog.");
  }
  EnumerationOwner enumeration(api, raw_enumeration);
  if (U_FAILURE(status)) {
    return Failure("icu-timezone-enumeration-open-failed",
                   "ICU could not open the time-zone catalog.");
  }

  status = U_ZERO_ERROR;
  const int32_t count = api.EnumerationCount(enumeration.get(), &status);
  if (U_FAILURE(status) || count < 0) {
    return Failure("icu-timezone-enumeration-count-failed",
                   "ICU could not count the available time zones.");
  }

  TimezoneOperationResult result{};
  result.values.reserve(static_cast<size_t>(count));
  for (int32_t index = 0; index < count; ++index) {
    status = U_ZERO_ERROR;
    int32_t value_length = 0;
    const char* value =
        api.EnumerationNext(enumeration.get(), &value_length, &status);
    if (U_FAILURE(status) || value == nullptr || value_length <= 0) {
      return Failure("icu-timezone-enumeration-read-failed",
                     "ICU could not read the time-zone catalog.");
    }
    result.values.emplace_back(value, static_cast<size_t>(value_length));
  }
  result.succeeded = true;
  return result;
}

}  // namespace flutter_timezone
