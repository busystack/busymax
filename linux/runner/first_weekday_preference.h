#ifndef BUSYMAX_FIRST_WEEKDAY_PREFERENCE_H_
#define BUSYMAX_FIRST_WEEKDAY_PREFERENCE_H_

#include <gio/gio.h>

#include <functional>
#include <memory>
#include <optional>

// Resolves GNOME's explicit calendar preference before the effective LC_TIME
// convention. Portal access is attempted first so strict packages observe the
// host setting even when their local schema set is incomplete.
class BusyMaxLinuxFirstWeekdayPreference {
 public:
  using ReadCallback = std::function<void(std::optional<int>)>;
  using ChangeCallback = std::function<void()>;
  using LocaleReader = std::function<std::optional<int>()>;

  struct Configuration {
    // Tests may supply a private bus connection and isolated schema source.
    // Production leaves both null to use the session bus and default source.
    GDBusConnection* portal_connection = nullptr;
    GSettingsSchemaSource* schema_source = nullptr;
    const char* direct_schema = "org.gnome.desktop.calendar";
    const char* direct_key = "week-start-day";
    LocaleReader locale_reader;
    guint portal_timeout_milliseconds = 1000;
  };

  BusyMaxLinuxFirstWeekdayPreference();
  explicit BusyMaxLinuxFirstWeekdayPreference(Configuration configuration);
  ~BusyMaxLinuxFirstWeekdayPreference();

  BusyMaxLinuxFirstWeekdayPreference(
      const BusyMaxLinuxFirstWeekdayPreference&) = delete;
  BusyMaxLinuxFirstWeekdayPreference& operator=(
      const BusyMaxLinuxFirstWeekdayPreference&) = delete;

  void Read(ReadCallback callback);
  void CancelRead();
  void StartWatching(ChangeCallback callback);
  void StopWatching();

 private:
  struct State;
  std::shared_ptr<State> state_;
};

#endif  // BUSYMAX_FIRST_WEEKDAY_PREFERENCE_H_
