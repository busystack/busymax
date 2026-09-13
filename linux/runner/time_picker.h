#ifndef BUSYMAX_TIME_PICKER_H_
#define BUSYMAX_TIME_PICKER_H_

#include <gtk/gtk.h>
#include <cstring>
#include <utility>
#include <initializer_list>

namespace busymax_time_picker {

inline bool ParseCanonical(const char* text, unsigned* hour, unsigned* minute) {
  if (!text || std::strlen(text) != 5 || text[2] != ':') return false;
  for (const int index : {0, 1, 3, 4}) {
    if (text[index] < '0' || text[index] > '9') return false;
  }
  const unsigned h = (text[0] - '0') * 10 + text[1] - '0';
  const unsigned m = (text[3] - '0') * 10 + text[4] - '0';
  if (h > 23 || m > 59) return false;
  *hour = h;
  *minute = m;
  return true;
}

inline int DisplayHour(int hour) { return (hour + 11) % 12 + 1; }
inline int CanonicalHour(int hour, bool pm) { return hour % 12 + (pm ? 12 : 0); }

// Used by the optional GTK path and its native control tests.
struct Controls {
  GtkWidget* row;
  GtkSpinButton* hour;
  GtkSpinButton* minute;
  GtkComboBox* period;
  bool use24;

  Controls(bool use24, unsigned initial_hour, unsigned initial_minute,
           const char* hour_label, const char* minute_label,
           const char* period_label, const char* am, const char* pm)
      : use24(use24) {
    row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    hour = GTK_SPIN_BUTTON(gtk_spin_button_new_with_range(use24 ? 0 : 1, use24 ? 23 : 12, 1));
    minute = GTK_SPIN_BUTTON(gtk_spin_button_new_with_range(0, 59, 1));
    period = GTK_COMBO_BOX(gtk_combo_box_text_new());
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(period), am);
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(period), pm);
    gtk_combo_box_set_active(period, initial_hour >= 12 ? 1 : 0);
    gtk_spin_button_set_numeric(hour, TRUE);
    gtk_spin_button_set_numeric(minute, TRUE);
    gtk_spin_button_set_wrap(hour, TRUE);
    gtk_spin_button_set_wrap(minute, TRUE);
    gtk_spin_button_set_value(hour, use24 ? initial_hour : DisplayHour(initial_hour));
    gtk_spin_button_set_value(minute, initial_minute);
    gtk_widget_set_size_request(GTK_WIDGET(hour), 70, -1);
    gtk_widget_set_size_request(GTK_WIDGET(minute), 70, -1);
    for (auto pair : {std::pair<GtkWidget*, const char*>(GTK_WIDGET(hour), hour_label),
                      std::pair<GtkWidget*, const char*>(GTK_WIDGET(minute), minute_label),
                      std::pair<GtkWidget*, const char*>(GTK_WIDGET(period), period_label)}) {
      GtkWidget* label = gtk_label_new(pair.second);
      gtk_label_set_mnemonic_widget(GTK_LABEL(label), pair.first);
      atk_object_set_name(gtk_widget_get_accessible(pair.first), pair.second);
      gtk_container_add(GTK_CONTAINER(row), label);
      gtk_container_add(GTK_CONTAINER(row), pair.first);
      if (pair.first == GTK_WIDGET(period) && use24) {
        gtk_widget_set_no_show_all(label, TRUE);
        gtk_widget_set_no_show_all(pair.first, TRUE);
      }
    }
  }

  int selected_hour() const {
    const int value = gtk_spin_button_get_value_as_int(hour);
    return use24 ? value : CanonicalHour(value, gtk_combo_box_get_active(period) == 1);
  }
};
}  // namespace busymax_time_picker
#endif
