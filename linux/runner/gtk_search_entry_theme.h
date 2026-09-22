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
  gboolean has_inner_focus;
  GdkRGBA inner_focus_color;
  gint inner_focus_width;
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

// Applies the small compatibility model needed to reproduce Yaru's native
// Search-entry geometry. Yaru keeps a normal one-pixel CSS border and adds a
// separate one-pixel inset focus stroke; it does not replace the border with a
// two-pixel stroke. This helper is public so production and native tests use
// exactly the same policy.
void busymax_apply_yaru_search_entry_compatibility(
    BusyMaxGtkSearchEntryTheme* theme);

// Samples the effective GtkSearchEntry icon foreground. The primary Find icon
// is sampled with GTK_STATE_FLAG_INSENSITIVE because GtkSearchEntry configures
// primary-icon-sensitive=FALSE. The secondary Clear icon remains sensitive.
// Logical primary/secondary positions are mapped to physical
// image.left/image.right nodes according to text direction.
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
