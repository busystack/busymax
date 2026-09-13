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

// Read the entry, not the adjustment: GTK may not have committed typed text
// yet, and its default update policy clamps out-of-range edits.
inline bool ReadComponent(GtkSpinButton* spin, unsigned* result) {
  const char* text = gtk_entry_get_text(GTK_ENTRY(spin));
  const size_t length = std::strlen(text);
  if (length == 0 || length > 2) return false;
  unsigned value = 0;
  for (size_t index = 0; index < length; ++index) {
    if (text[index] < '0' || text[index] > '9') return false;
    value = value * 10 + text[index] - '0';
  }
  double lower, upper;
  gtk_spin_button_get_range(spin, &lower, &upper);
  if (value < lower || value > upper) return false;
  *result = value;
  return true;
}

inline void PreserveInvalidComponent(GtkSpinButton* spin) {
  gtk_spin_button_set_update_policy(spin, GTK_UPDATE_IF_VALID);
  g_signal_connect(spin, "input", G_CALLBACK(+[](
      GtkSpinButton* input, gdouble* value, gpointer) -> gint {
    unsigned component;
    if (!ReadComponent(input, &component)) return GTK_INPUT_ERROR;
    *value = component;
    return TRUE;
  }), nullptr);
  g_signal_connect(spin, "output", G_CALLBACK(+[](
      GtkSpinButton* output, gpointer) -> gboolean {
    unsigned component;
    // GTK_UPDATE_IF_VALID still redraws the previous numeric value on an
    // invalid update (e.g. focus-out). Suppress that redraw so confirmation
    // can validate the original text and the user can correct it in place.
    return !ReadComponent(output, &component);
  }), nullptr);
}

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
    PreserveInvalidComponent(hour);
    PreserveInvalidComponent(minute);
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

  bool ReadTime(unsigned* selected_hour, unsigned* selected_minute) const {
    unsigned h, m;
    if (!ReadComponent(hour, &h) || !ReadComponent(minute, &m)) return false;
    const int selected_period = gtk_combo_box_get_active(period);
    if (!use24 && selected_period != 0 && selected_period != 1) return false;
    *selected_hour = use24 ? h : CanonicalHour(h, selected_period == 1);
    *selected_minute = m;
    return true;
  }
};

// Shared by the runner and native interaction tests. Reject the response before
// gtk_dialog_run's response handler sees it, keeping the same dialog and draft.
// Only a valid OK writes outputs; cancellation leaves them untouched.
inline bool RunDialog(GtkDialog* dialog, const Controls& controls,
                      const char* invalid_label, unsigned* hour,
                      unsigned* minute) {
  GtkWidget* error = gtk_label_new(invalid_label);
  gtk_label_set_line_wrap(GTK_LABEL(error), TRUE);
  gtk_widget_set_no_show_all(error, TRUE);
  gtk_style_context_add_class(gtk_widget_get_style_context(error), "error");
  gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(dialog)), error);
  struct Confirmation {
    const Controls& controls;
    GtkWidget* error;
    unsigned* hour;
    unsigned* minute;
  } confirmation{controls, error, hour, minute};
  const gulong handler = g_signal_connect(dialog, "response", G_CALLBACK(+[](
      GtkDialog* dialog, gint response, gpointer data) {
    if (response != GTK_RESPONSE_OK) return;
    auto& state = *static_cast<Confirmation*>(data);
    if (state.controls.ReadTime(state.hour, state.minute)) return;
    g_signal_stop_emission_by_name(dialog, "response");
    gtk_widget_show(state.error);
    GtkWidget* first_invalid = nullptr;
    for (auto* spin : {state.controls.hour, state.controls.minute}) {
      unsigned value;
      const bool valid = ReadComponent(spin, &value);
      GtkWidget* widget = GTK_WIDGET(spin);
      auto* style = gtk_widget_get_style_context(widget);
      if (valid) {
        gtk_style_context_remove_class(style, "error");
      } else {
        gtk_style_context_add_class(style, "error");
        if (!first_invalid) first_invalid = widget;
      }
    }
    gtk_widget_grab_focus(first_invalid ? first_invalid
                                      : GTK_WIDGET(state.controls.period));
  }), &confirmation);
  const gint response = gtk_dialog_run(dialog);
  g_signal_handler_disconnect(dialog, handler);
  return response == GTK_RESPONSE_OK;
}
}  // namespace busymax_time_picker
#endif
