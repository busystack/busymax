#include "../time_picker.h"
#include <cassert>
#include <cstdio>

namespace {

enum class Commit { direct, update, focus_out, activate };

void TestInvalidConfirmation(bool use24, bool invalid_hour, const char* text,
                             Commit commit, bool cancel) {
  GtkWidget* dialog = gtk_dialog_new_with_buttons(
      "Time", nullptr, GTK_DIALOG_MODAL, "Cancel", GTK_RESPONSE_CANCEL,
      "OK", GTK_RESPONSE_OK, nullptr);
  gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
  busymax_time_picker::Controls controls(
      use24, 14, 5, "Stunde", "Minute", "Tageszeit", "AM", "PM");
  gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))),
                    controls.row);
  gtk_widget_show_all(dialog);
  struct Interaction {
    GtkDialog* dialog;
    busymax_time_picker::Controls& controls;
    bool invalid_hour;
    const char* text;
    Commit commit;
    bool cancel;
    unsigned hour = 99;
    unsigned minute = 99;
    int phase = 0;
    int responses = 0;
  } interaction{GTK_DIALOG(dialog), controls, invalid_hour, text, commit, cancel};
  const guint watchdog = g_timeout_add_seconds(10, +[](gpointer) -> gboolean {
    g_error("Native time-picker confirmation test timed out");
    return G_SOURCE_REMOVE;
  }, nullptr);
  g_idle_add(+[](gpointer data) -> gboolean {
    auto& state = *static_cast<Interaction*>(data);
    auto* spin = state.invalid_hour ? state.controls.hour : state.controls.minute;
    if (state.phase++ == 0) {
      // Connected after RunDialog's validator: invalid responses must never
      // reach downstream handlers, including gtk_dialog_run's completion.
      g_signal_connect(state.dialog, "response", G_CALLBACK(+[](
          GtkDialog*, gint, gpointer data) {
        ++static_cast<Interaction*>(data)->responses;
      }), data);
      gtk_widget_grab_focus(GTK_WIDGET(spin));
      gtk_entry_set_text(GTK_ENTRY(spin), state.text);
      switch (state.commit) {
        case Commit::direct:
          break;
        case Commit::update:
          gtk_spin_button_update(spin);
          break;
        case Commit::focus_out: {
          GdkEventFocus event{};
          event.type = GDK_FOCUS_CHANGE;
          event.in = FALSE;
          gboolean handled = FALSE;
          g_signal_emit_by_name(spin, "focus-out-event", &event, &handled);
          break;
        }
        case Commit::activate:
          g_signal_emit_by_name(spin, "activate");
          break;
      }
      // A real OK response, with the same validation path used by the runner.
      gtk_button_clicked(GTK_BUTTON(gtk_dialog_get_widget_for_response(
          state.dialog, GTK_RESPONSE_OK)));
      assert(state.responses == 0);
      assert(state.hour == 99 && state.minute == 99);
      if (std::strcmp(gtk_entry_get_text(GTK_ENTRY(spin)), state.text) != 0) {
        std::fprintf(stderr, "Changed entry (24h=%d, hour=%d, commit=%d): '%s' -> '%s'\n",
                     state.controls.use24, state.invalid_hour,
                     static_cast<int>(state.commit), state.text,
                     gtk_entry_get_text(GTK_ENTRY(spin)));
      }
      assert(std::strcmp(gtk_entry_get_text(GTK_ENTRY(spin)), state.text) == 0);
      assert(gtk_widget_get_visible(GTK_WIDGET(state.dialog)));
      assert(gtk_style_context_has_class(
          gtk_widget_get_style_context(GTK_WIDGET(spin)), "error"));
      GList* children = gtk_container_get_children(GTK_CONTAINER(
          gtk_dialog_get_content_area(state.dialog)));
      bool found_error = false;
      for (GList* child = children; child; child = child->next) {
        if (GTK_IS_LABEL(child->data) &&
            std::strcmp(gtk_label_get_text(GTK_LABEL(child->data)),
                        "Ungueltige Zeit") == 0) {
          found_error = gtk_widget_get_visible(GTK_WIDGET(child->data));
        }
      }
      g_list_free(children);
      assert(found_error);
      return G_SOURCE_CONTINUE;
    }
    // Repeated confirmation still cannot save the old/clamped value.
    gtk_dialog_response(state.dialog, GTK_RESPONSE_OK);
    assert(state.responses == 0);
    assert(state.hour == 99 && state.minute == 99);
    if (!state.cancel) {
      // Do not update either adjustment: acceptance must read the new text.
      gtk_entry_set_text(GTK_ENTRY(state.controls.hour), state.controls.use24 ? "23" : "12");
      gtk_entry_set_text(GTK_ENTRY(state.controls.minute), "59");
      gtk_combo_box_set_active(state.controls.period, 0);
    }
    gtk_button_clicked(GTK_BUTTON(gtk_dialog_get_widget_for_response(
        state.dialog, state.cancel ? GTK_RESPONSE_CANCEL : GTK_RESPONSE_OK)));
    return G_SOURCE_REMOVE;
  }, &interaction);
  const bool accepted = busymax_time_picker::RunDialog(
      GTK_DIALOG(dialog), controls, "Ungueltige Zeit", &interaction.hour,
      &interaction.minute);
  assert(accepted == !cancel);
  assert(interaction.phase == 2 && interaction.responses == 1);
  assert(interaction.hour == (cancel ? 99u : use24 ? 23u : 0u));
  assert(interaction.minute == (cancel ? 99u : 59u));
  g_source_remove(watchdog);
  gtk_widget_destroy(dialog);
}

}  // namespace

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
      unsigned selected_hour = 99, selected_minute = 99;
      assert(controls.ReadTime(&selected_hour, &selected_minute));
      assert(selected_hour == hour && selected_minute == 5);
      assert(gtk_spin_button_get_value_as_int(controls.minute) == 5);
      assert(gtk_spin_button_get_value_as_int(controls.hour) == (use24 ? static_cast<int>(hour) : busymax_time_picker::DisplayHour(hour)));
      if (!use24) {
        gtk_combo_box_set_active(controls.period, hour >= 12 ? 0 : 1);
        assert(controls.ReadTime(&selected_hour, &selected_minute));
        assert(selected_hour == (hour + 12) % 24 && selected_minute == 5);
      }
      gtk_widget_destroy(controls.row);
    }
  }
  for (const bool use24 : {false, true}) {
    for (const Commit commit : {Commit::direct, Commit::update,
                               Commit::focus_out, Commit::activate}) {
      for (const char* text : {use24 ? "24" : "13", use24 ? "99" : "00",
                               "", "-1", "001"}) {
        TestInvalidConfirmation(use24, true, text, commit, false);
      }
      for (const char* text : {"60", "99", "", "-1", "001"}) {
        TestInvalidConfirmation(use24, false, text, commit, false);
      }
      TestInvalidConfirmation(use24, true, use24 ? "24" : "13", commit, true);
      TestInvalidConfirmation(use24, false, "60", commit, true);
    }
  }
  puts("Native GTK parsing, conversion, controls and dialog validation passed.");
}
