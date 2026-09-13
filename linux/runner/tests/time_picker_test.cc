#include "../time_picker.h"
#include <cassert>
#include <cstdio>

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  for (unsigned minutes = 0; minutes < 1440; ++minutes) {
    char text[6];
    std::snprintf(text, sizeof(text), "%02u:%02u", minutes / 60, minutes % 60);
    unsigned hour = 99, minute = 99;
    assert(busymax_time_picker::ParseCanonical(text, &hour, &minute));
    assert(hour * 60 + minute == minutes);
    assert(busymax_time_picker::CanonicalHour(
        busymax_time_picker::DisplayHour(hour), hour >= 12) == static_cast<int>(hour));
  }
  for (const char* text : {"0:00", "24:00", "12:60", "12:00 AM", "12:00x", " 12:00", "12:0", "-1:00"}) {
    unsigned hour = 99, minute = 99;
    assert(!busymax_time_picker::ParseCanonical(text, &hour, &minute));
    assert(hour == 99 && minute == 99);
  }
  for (const bool use24 : {false, true}) {
    for (unsigned hour = 0; hour < 24; ++hour) {
      busymax_time_picker::Controls controls(use24, hour, 5, "Stunde", "Minute", "Tageszeit", "AM", "PM");
      assert(controls.selected_hour() == static_cast<int>(hour));
      assert(gtk_spin_button_get_value_as_int(controls.minute) == 5);
      assert(gtk_spin_button_get_value_as_int(controls.hour) == (use24 ? static_cast<int>(hour) : busymax_time_picker::DisplayHour(hour)));
      if (!use24) {
        gtk_combo_box_set_active(controls.period, hour >= 12 ? 0 : 1);
        assert(controls.selected_hour() == static_cast<int>((hour + 12) % 24));
      }
      gtk_widget_destroy(controls.row);
    }
  }
  puts("Native GTK clock parsing, conversion and controls passed.");
}
