#ifndef RUNNER_GTK_WINDOW_PREFERENCES_H_
#define RUNNER_GTK_WINDOW_PREFERENCES_H_

#include <gtk/gtk.h>

#include <array>
#include <functional>
#include <string>

struct BusyMaxGtkWindowPreferences {
  std::string decoration_layout;
  std::string double_click;
  std::string middle_click;
  std::string right_click;
};

class BusyMaxGtkWindowPreferencesWatcher {
 public:
  using ChangedCallback =
      std::function<void(const BusyMaxGtkWindowPreferences&)>;

  explicit BusyMaxGtkWindowPreferencesWatcher(GtkSettings* settings = nullptr);
  ~BusyMaxGtkWindowPreferencesWatcher();

  BusyMaxGtkWindowPreferencesWatcher(
      const BusyMaxGtkWindowPreferencesWatcher&) = delete;
  BusyMaxGtkWindowPreferencesWatcher& operator=(
      const BusyMaxGtkWindowPreferencesWatcher&) = delete;

  BusyMaxGtkWindowPreferences Read() const;
  static BusyMaxGtkWindowPreferences Defaults();
  bool Start(ChangedCallback callback);
  void Stop();

  std::array<gulong, 4> signal_ids() const;

 private:
  static void OnSettingChanged(GObject* object,
                               GParamSpec* specification,
                               gpointer user_data);
  GtkSettings* ResolveSettings() const;

  GtkSettings* settings_;
  ChangedCallback callback_;
  std::array<gulong, 4> signal_ids_ = {0, 0, 0, 0};
};

#endif  // RUNNER_GTK_WINDOW_PREFERENCES_H_
