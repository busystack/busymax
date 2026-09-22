#include "gtk_search_entry_theme.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace {

bool IsFiniteColor(const GdkRGBA& color) {
  return std::isfinite(color.red) && std::isfinite(color.green) &&
         std::isfinite(color.blue) && std::isfinite(color.alpha);
}

bool ReadColorProperty(GtkStyleContext* context,
                       GtkStateFlags state,
                       const gchar* property,
                       GdkRGBA* color) {
  GValue value = G_VALUE_INIT;
  gtk_style_context_get_property(context, property, state, &value);
  const GdkRGBA* sampled =
      static_cast<const GdkRGBA*>(g_value_get_boxed(&value));
  const bool valid = sampled != nullptr && IsFiniteColor(*sampled);
  if (valid) {
    *color = *sampled;
  }
  g_value_unset(&value);
  return valid;
}

bool ReadRadius(GtkStyleContext* context,
                GtkStateFlags state,
                gint* radius) {
  GValue value = G_VALUE_INIT;
  gtk_style_context_get_property(
      context, GTK_STYLE_PROPERTY_BORDER_RADIUS, state, &value);
  const bool valid = G_VALUE_HOLDS_INT(&value);
  if (valid) {
    *radius = g_value_get_int(&value);
  }
  g_value_unset(&value);
  return valid && *radius >= 0;
}

}  // namespace

bool busymax_sample_gtk_search_entry_icon_foreground(
    GtkStyleContext* entry_context,
    GtkStateFlags state,
    GtkEntryIconPosition icon_position,
    GtkTextDirection direction,
    GdkRGBA* color) {
  if (entry_context == nullptr || color == nullptr ||
      (icon_position != GTK_ENTRY_ICON_PRIMARY &&
       icon_position != GTK_ENTRY_ICON_SECONDARY) ||
      (direction != GTK_TEXT_DIR_LTR && direction != GTK_TEXT_DIR_RTL)) {
    return false;
  }
  const GtkWidgetPath* entry_path =
      gtk_style_context_get_path(entry_context);
  if (entry_path == nullptr) {
    return false;
  }

  GtkWidgetPath* image_path = gtk_widget_path_copy(entry_path);
  const gint image_position =
      gtk_widget_path_append_type(image_path, GTK_TYPE_IMAGE);
  GtkStateFlags icon_state = static_cast<GtkStateFlags>(
      state | (direction == GTK_TEXT_DIR_RTL ? GTK_STATE_FLAG_DIR_RTL
                                             : GTK_STATE_FLAG_DIR_LTR));
  if (icon_position == GTK_ENTRY_ICON_PRIMARY) {
    icon_state = static_cast<GtkStateFlags>(icon_state |
                                            GTK_STATE_FLAG_INSENSITIVE);
  }
  const bool physical_left =
      (direction == GTK_TEXT_DIR_LTR &&
       icon_position == GTK_ENTRY_ICON_PRIMARY) ||
      (direction == GTK_TEXT_DIR_RTL &&
       icon_position == GTK_ENTRY_ICON_SECONDARY);
  gtk_widget_path_iter_set_object_name(image_path, image_position, "image");
  gtk_widget_path_iter_add_class(
      image_path, image_position,
      physical_left ? GTK_STYLE_CLASS_LEFT : GTK_STYLE_CLASS_RIGHT);
  gtk_widget_path_iter_set_state(image_path, image_position, icon_state);

  GtkStyleContext* image_context = gtk_style_context_new();
  gtk_style_context_set_path(image_context, image_path);
  gtk_style_context_set_parent(image_context, entry_context);
  gtk_style_context_add_class(
      image_context,
      physical_left ? GTK_STYLE_CLASS_LEFT : GTK_STYLE_CLASS_RIGHT);
  gtk_style_context_set_state(image_context, icon_state);
  gtk_style_context_get_color(image_context, icon_state, color);

  const bool valid = IsFiniteColor(*color);
  g_object_unref(image_context);
  gtk_widget_path_free(image_path);
  return valid;
}

namespace {

bool SampleState(GtkStyleContext* context,
                 GtkStateFlags state,
                 BusyMaxGtkSearchEntryState* result) {
  gtk_style_context_set_state(context, state);

  const bool has_background = ReadColorProperty(
      context, state, GTK_STYLE_PROPERTY_BACKGROUND_COLOR,
      &result->background);
  gtk_style_context_get_color(context, state, &result->foreground);
  const bool has_foreground = IsFiniteColor(result->foreground);
  const bool has_border = ReadColorProperty(
      context, state, GTK_STYLE_PROPERTY_BORDER_COLOR,
      &result->border_color);
  gtk_style_context_get_border(context, state, &result->border_width);
  const bool has_radius = ReadRadius(context, state, &result->border_radius);
  const bool has_primary_ltr =
      busymax_sample_gtk_search_entry_icon_foreground(
          context, state, GTK_ENTRY_ICON_PRIMARY, GTK_TEXT_DIR_LTR,
          &result->primary_icon_foreground);
  const bool has_primary_rtl =
      busymax_sample_gtk_search_entry_icon_foreground(
          context, state, GTK_ENTRY_ICON_PRIMARY, GTK_TEXT_DIR_RTL,
          &result->primary_icon_foreground_rtl);
  const bool has_secondary_ltr =
      busymax_sample_gtk_search_entry_icon_foreground(
          context, state, GTK_ENTRY_ICON_SECONDARY, GTK_TEXT_DIR_LTR,
          &result->secondary_icon_foreground);
  const bool has_secondary_rtl =
      busymax_sample_gtk_search_entry_icon_foreground(
          context, state, GTK_ENTRY_ICON_SECONDARY, GTK_TEXT_DIR_RTL,
          &result->secondary_icon_foreground_rtl);

  return has_background && has_foreground && has_border && has_radius &&
         has_primary_ltr && has_primary_rtl && has_secondary_ltr &&
         has_secondary_rtl && result->border_width.top >= 0 &&
         result->border_width.right >= 0 &&
         result->border_width.bottom >= 0 && result->border_width.left >= 0;
}

}  // namespace

bool busymax_gtk_theme_is_standard_yaru(const gchar* theme_name) {
  if (theme_name == nullptr) {
    return false;
  }
  g_autofree gchar* normalized = g_ascii_strdown(theme_name, -1);
  const bool is_yaru = g_strcmp0(normalized, "yaru") == 0 ||
                       g_str_has_prefix(normalized, "yaru-");
  return is_yaru && std::strstr(normalized, "highcontrast") == nullptr &&
         std::strstr(normalized, "high-contrast") == nullptr;
}

bool busymax_sample_gtk_search_entry_theme(
    BusyMaxGtkSearchEntryTheme* theme) {
  if (theme == nullptr) {
    return false;
  }

  GtkWidget* search_entry = gtk_search_entry_new();
  g_object_ref_sink(search_entry);
  GtkStyleContext* context = gtk_widget_get_style_context(search_entry);
  const bool sampled =
      SampleState(context, GTK_STATE_FLAG_NORMAL, &theme->normal) &&
      SampleState(context, GTK_STATE_FLAG_FOCUSED, &theme->focused) &&
      SampleState(context, GTK_STATE_FLAG_BACKDROP, &theme->backdrop) &&
      SampleState(context,
                  static_cast<GtkStateFlags>(GTK_STATE_FLAG_BACKDROP |
                                             GTK_STATE_FLAG_FOCUSED),
                  &theme->backdrop_focused);

  GtkSettings* settings = gtk_settings_get_default();
  g_autofree gchar* theme_name = nullptr;
  if (settings != nullptr) {
    g_object_get(settings, "gtk-theme-name", &theme_name, nullptr);
  }
  if (sampled && busymax_gtk_theme_is_standard_yaru(theme_name)) {
    constexpr gint kBusyMaxYaruSearchEntryRadius = 9;
    constexpr gint kBusyMaxYaruFocusedBorderWidth = 2;
    theme->normal.border_radius = kBusyMaxYaruSearchEntryRadius;
    theme->focused.border_radius = kBusyMaxYaruSearchEntryRadius;
    theme->backdrop.border_radius = kBusyMaxYaruSearchEntryRadius;
    theme->backdrop_focused.border_radius = kBusyMaxYaruSearchEntryRadius;
    // Yaru's remaining focused weight is a box shadow. BusyMax intentionally
    // does not emulate arbitrary GTK shadows, so retain the established 2px
    // active focus edge while preserving GTK's backdrop-focused geometry.
    theme->focused.border_width.top = std::max<gint>(
        theme->focused.border_width.top, kBusyMaxYaruFocusedBorderWidth);
    theme->focused.border_width.right = std::max<gint>(
        theme->focused.border_width.right, kBusyMaxYaruFocusedBorderWidth);
    theme->focused.border_width.bottom = std::max<gint>(
        theme->focused.border_width.bottom, kBusyMaxYaruFocusedBorderWidth);
    theme->focused.border_width.left = std::max<gint>(
        theme->focused.border_width.left, kBusyMaxYaruFocusedBorderWidth);
  }

  gtk_widget_destroy(search_entry);
  g_object_unref(search_entry);
  return sampled;
}
