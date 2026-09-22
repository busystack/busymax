#ifndef RUNNER_GTK_SEARCH_ENTRY_THEME_H_
#define RUNNER_GTK_SEARCH_ENTRY_THEME_H_

#include <gtk/gtk.h>

struct BusyMaxGtkSearchEntryState {
  GdkRGBA background;
  GdkRGBA foreground;
  GdkRGBA border_color;
  GdkRGBA primary_icon_foreground;
  GdkRGBA primary_icon_foreground_rtl;
  GdkRGBA secondary_icon_foreground;
  GdkRGBA secondary_icon_foreground_rtl;
  GtkBorder border_width;
  gint border_radius;
};

struct BusyMaxGtkSearchEntryTheme {
  BusyMaxGtkSearchEntryState normal;
  BusyMaxGtkSearchEntryState focused;
  BusyMaxGtkSearchEntryState backdrop;
  BusyMaxGtkSearchEntryState backdrop_focused;
};

// Uses the same theme-name classification as BusyMax's pre-Flutter-header
// compatibility treatment. This helper is public so the production sampler
// and its native test cannot drift apart.
bool busymax_gtk_theme_is_standard_yaru(const gchar* theme_name);

// Samples the logical icon role from the physical image.left/image.right CSS
// node selected by GtkEntry for the supplied text direction.
bool busymax_sample_gtk_search_entry_icon_foreground(
    GtkStyleContext* entry_context,
    GtkStateFlags state,
    GtkEntryIconPosition icon_position,
    GtkTextDirection direction,
    GdkRGBA* color);

// Samples an actual GtkSearchEntry and copies all results into owned values.
// No GtkWidget or GtkStyleContext escapes this function.
bool busymax_sample_gtk_search_entry_theme(
    BusyMaxGtkSearchEntryTheme* theme);

#endif  // RUNNER_GTK_SEARCH_ENTRY_THEME_H_
