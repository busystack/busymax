#ifndef FLUTTER_TIMEZONE_TIMEZONE_NATIVE_API_H_
#define FLUTTER_TIMEZONE_TIMEZONE_NATIVE_API_H_

// Windows must precede ICU headers.
#include <windows.h>

#define UCHAR_TYPE wchar_t
#include <icu.h>

#include <cstdint>
#include <string>
#include <vector>

namespace flutter_timezone {

struct TimezoneOperationResult {
  bool succeeded = false;
  std::string value;
  std::vector<std::string> values;
  std::string error_code;
  std::string error_message;
};

// Kept behind an interface so every Win32 and ICU failure can be exercised by
// native tests without changing process or machine state.
class TimezoneNativeApi {
 public:
  virtual ~TimezoneNativeApi() = default;

  virtual DWORD GetDynamicTimeZoneInformation(
      DYNAMIC_TIME_ZONE_INFORMATION* information) = 0;
  virtual int GetUserDefaultGeoName(wchar_t* buffer, int capacity) = 0;
  virtual int32_t GetTimeZoneIdForWindowsId(
      const UChar* windows_id,
      int32_t windows_id_length,
      const char* region,
      UChar* result,
      int32_t result_capacity,
      UErrorCode* status) = 0;
  virtual UEnumeration* OpenTimeZoneIdEnumeration(UErrorCode* status) = 0;
  virtual int32_t EnumerationCount(UEnumeration* enumeration,
                                   UErrorCode* status) = 0;
  virtual const char* EnumerationNext(UEnumeration* enumeration,
                                      int32_t* result_length,
                                      UErrorCode* status) = 0;
  virtual void CloseEnumeration(UEnumeration* enumeration) = 0;
};

class WindowsTimezoneNativeApi final : public TimezoneNativeApi {
 public:
  DWORD GetDynamicTimeZoneInformation(
      DYNAMIC_TIME_ZONE_INFORMATION* information) override;
  int GetUserDefaultGeoName(wchar_t* buffer, int capacity) override;
  int32_t GetTimeZoneIdForWindowsId(const UChar* windows_id,
                                    int32_t windows_id_length,
                                    const char* region,
                                    UChar* result,
                                    int32_t result_capacity,
                                    UErrorCode* status) override;
  UEnumeration* OpenTimeZoneIdEnumeration(UErrorCode* status) override;
  int32_t EnumerationCount(UEnumeration* enumeration,
                           UErrorCode* status) override;
  const char* EnumerationNext(UEnumeration* enumeration,
                              int32_t* result_length,
                              UErrorCode* status) override;
  void CloseEnumeration(UEnumeration* enumeration) override;
};

TimezoneOperationResult ResolveLocalTimezone(TimezoneNativeApi& api);
TimezoneOperationResult EnumerateTimezones(TimezoneNativeApi& api);

}  // namespace flutter_timezone

#endif  // FLUTTER_TIMEZONE_TIMEZONE_NATIVE_API_H_
