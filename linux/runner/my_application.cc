#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <pango/pango.h>
#include <cmath>
#include <cstdio>
#include <cstring>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"

constexpr char kApplicationDisplayName[] = "BusyMax";
constexpr char kNativeDateTimePickerChannel[] =
    "busymax/native_date_time_picker";
constexpr char kWindowChannel[] = "io.busystack.busymax/window";
constexpr char kHeaderBarChannel[] = "io.busystack.busymax/headerbar";
constexpr char kGtkSettingsChannel[] = "io.busystack.busymax/gtk_settings";
constexpr char kGtkFontSettingsEventChannel[] =
    "io.busystack.busymax/gtk_font_settings";
constexpr char kGtkThemeColorsEventChannel[] =
    "io.busystack.busymax/gtk_theme_colors";
constexpr char kCompactAgendaWindowChannel[] =
    "io.busystack.busymax/compact_agenda_window";
constexpr gint kHeaderButtonHeight = 34;
constexpr gint kHeaderButtonRadius = 8;
constexpr gint kHeaderButtonHorizontalPadding = 8;
constexpr gint kHeaderButtonSpacing = 6;
constexpr gint kHeaderWindowControlsBalanceWidth =
    kHeaderButtonHeight * 3 + kHeaderButtonSpacing * 2;
constexpr gint kHeaderOnboardingContentWidth = 480;
constexpr gint kHeaderOnboardingSideWidth = 120;
constexpr gint kHeaderMenuPadding = kHeaderButtonSpacing;
constexpr gint kHeaderPopoverRowSpacing = 4;
constexpr gint kHeaderSidebarContentInset = kHeaderButtonSpacing;
constexpr gint kHeaderMainContentStartInset = kHeaderSidebarContentInset;
constexpr gint kHeaderTooltipVerticalPadding = 5;
constexpr gint kHeaderTooltipHorizontalPadding = 8;
constexpr gint kHeaderWindowRadius = 8;
constexpr gint kCompactAgendaPanelWidth = 420;
constexpr gint kCompactAgendaPanelHeight = 680;
constexpr gint kCompactAgendaWindowShadowMargin = 32;
constexpr gint kCompactAgendaWindowWidth =
    kCompactAgendaPanelWidth + kCompactAgendaWindowShadowMargin * 2;
constexpr gint kCompactAgendaWindowHeight =
    kCompactAgendaPanelHeight + kCompactAgendaWindowShadowMargin * 2;
constexpr gint kCompactAgendaWindowMinWidth =
    360 + kCompactAgendaWindowShadowMargin * 2;
constexpr gint kCompactAgendaWindowMinHeight =
    520 + kCompactAgendaWindowShadowMargin * 2;
constexpr gint kCompactAgendaWindowMaxWidth =
    480 + kCompactAgendaWindowShadowMargin * 2;
constexpr gint kCompactAgendaWindowMaxHeight =
    840 + kCompactAgendaWindowShadowMargin * 2;
constexpr char kDefaultHeaderBarBackgroundColor[] = "#1D1D20";
constexpr char kDefaultHeaderBarSidebarBackgroundColor[] = "#2E2E32";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* native_date_time_picker_channel;
  FlMethodChannel* window_channel;
  FlMethodChannel* header_bar_channel;
  FlMethodChannel* gtk_settings_channel;
  FlEventChannel* gtk_font_settings_event_channel;
  FlEventChannel* gtk_theme_colors_event_channel;
  gulong gtk_font_settings_signal_id;
  gulong gtk_theme_name_signal_id;
  gulong gtk_theme_dark_signal_id;
  gboolean gtk_font_settings_listening;
  gboolean gtk_theme_colors_listening;
  GtkCssProvider* header_bar_css_provider;
  gchar* header_bar_window_background_color;
  gchar* header_bar_background_color;
  gchar* header_bar_sidebar_background_color;
  gchar* header_bar_foreground_color;
  gchar* header_bar_muted_foreground_color;
  gchar* header_bar_disabled_foreground_color;
  gchar* header_bar_control_color;
  gchar* header_bar_control_hover_color;
  gchar* header_bar_control_active_color;
  gchar* header_bar_accent_color;
  gchar* header_bar_accent_foreground_color;
  gchar* header_bar_popover_background_color;
  gchar* header_bar_border_color;
  gchar* header_bar_shade_color;
  gchar* header_bar_modal_barrier_color;
  gint header_bar_sidebar_width;
  gboolean header_bar_sidebar_visible;
  gboolean header_bar_modal_barrier_visible;
  GtkWindow* main_window;
  GtkWidget* flutter_view;
  GtkWidget* titlebar_box;
  GtkHeaderBar* header_bar;
  GtkWidget* header_start_box;
  GtkWidget* header_title_balance_spacer;
  GtkWidget* header_title_box;
  GtkWidget* onboarding_back_slot;
  GtkWidget* onboarding_back_button;
  GtkWidget* onboarding_continue_slot;
  GtkWidget* onboarding_continue_button;
  GtkWidget* header_sidebar_brand_box;
  GtkWidget* header_brand_label;
  GtkWidget* settings_menu_button;
  GtkWidget* settings_menu;
  GtkWidget* settings_item;
  GtkWidget* about_item;
  GtkWidget* header_view_box;
  GtkWidget* header_title_label;
  GtkWidget* back_button;
  GtkWidget* sidebar_collapsed_toggle_button;
  GtkWidget* today_button;
  GtkWidget* previous_button;
  GtkWidget* next_button;
  GtkWidget* view_mode_button;
  GtkWidget* view_mode_label;
  GtkWidget* view_mode_menu;
  GtkWidget* view_mode_day_item;
  GtkWidget* view_mode_week_item;
  GtkWidget* view_mode_month_item;
  GtkWidget* view_mode_year_item;
  GtkWidget* view_mode_agenda_item;
  GtkWidget* search_button;
  GtkWidget* refresh_button;
  gchar* header_view_mode;
  gboolean hide_on_close;
  gboolean suppress_header_bar_actions;
  gboolean header_schedule_controls_visible;
  gboolean header_navigation_visible;
  gboolean header_back_visible;
  gboolean header_onboarding_controls_visible;
  gboolean main_window_transparent_backing;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static GdkPixbuf* load_application_icon_at_size(gint size) {
  g_autofree gchar* executable_path =
      g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr) {
    return nullptr;
  }

  g_autofree gchar* executable_dir = g_path_get_dirname(executable_path);
  g_autofree gchar* icon_path =
      g_build_filename(executable_dir, "data", "flutter_assets", "assets",
                       "branding", "busymax-logo.png", nullptr);

  g_autoptr(GError) error = nullptr;
  GdkPixbuf* icon =
      gdk_pixbuf_new_from_file_at_size(icon_path, size, size, &error);
  if (icon == nullptr) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to load application icon: %s", message);
  }
  return icon;
}

static GdkPixbuf* load_application_icon() {
  return load_application_icon_at_size(256);
}

static const gchar* fl_lookup_string_arg(FlValue* args, const gchar* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

static gboolean fl_lookup_bool_arg(FlValue* args,
                                   const gchar* key,
                                   gboolean fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }
  return fl_value_get_bool(value);
}

static gboolean parse_date(const gchar* value,
                           guint* year,
                           guint* month,
                           guint* day) {
  if (value == nullptr) {
    return FALSE;
  }
  unsigned int parsed_year = 0;
  unsigned int parsed_month = 0;
  unsigned int parsed_day = 0;
  if (sscanf(value, "%u-%u-%u", &parsed_year, &parsed_month, &parsed_day) != 3) {
    return FALSE;
  }
  if (parsed_year < 1 || parsed_month < 1 || parsed_month > 12 ||
      parsed_day < 1 || parsed_day > 31) {
    return FALSE;
  }
  *year = parsed_year;
  *month = parsed_month;
  *day = parsed_day;
  return TRUE;
}

static void respond_string(FlMethodCall* method_call, const gchar* value) {
  g_autoptr(FlValue) result =
      value == nullptr ? fl_value_new_null() : fl_value_new_string(value);
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void handle_pick_date(FlMethodCall* method_call,
                             FlValue* args,
                             GtkWindow* parent) {
  const gchar* title = fl_lookup_string_arg(args, "title");
  const gchar* initial_date = fl_lookup_string_arg(args, "initialDate");
  const gchar* cancel_label = fl_lookup_string_arg(args, "cancelLabel");
  const gchar* ok_label = fl_lookup_string_arg(args, "okLabel");
  GtkWidget* dialog = gtk_dialog_new_with_buttons(
      title != nullptr ? title : "Date", parent, GTK_DIALOG_MODAL,
      cancel_label != nullptr ? cancel_label : "_Cancel", GTK_RESPONSE_CANCEL,
      ok_label != nullptr ? ok_label : "_OK", GTK_RESPONSE_OK, nullptr);
  gtk_window_set_resizable(GTK_WINDOW(dialog), FALSE);

  GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
  GtkWidget* calendar = gtk_calendar_new();
  gtk_container_set_border_width(GTK_CONTAINER(content), 12);
  gtk_container_add(GTK_CONTAINER(content), calendar);

  guint year = 0;
  guint month = 0;
  guint day = 0;
  if (parse_date(initial_date, &year, &month, &day)) {
    gtk_calendar_select_month(GTK_CALENDAR(calendar), month - 1, year);
    gtk_calendar_select_day(GTK_CALENDAR(calendar), day);
  }

  gtk_widget_show_all(dialog);
  const gint response = gtk_dialog_run(GTK_DIALOG(dialog));

  if (response == GTK_RESPONSE_OK) {
    gtk_calendar_get_date(GTK_CALENDAR(calendar), &year, &month, &day);
    g_autofree gchar* result =
        g_strdup_printf("%04u-%02u-%02u", year, month + 1, day);
    respond_string(method_call, result);
  } else {
    respond_string(method_call, nullptr);
  }

  gtk_widget_destroy(dialog);
}

static void native_date_time_picker_method_call_cb(FlMethodChannel* channel,
                                                   FlMethodCall* method_call,
                                                   gpointer user_data) {
  GtkWindow* parent = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (strcmp(method, "pickDate") == 0) {
    handle_pick_date(method_call, args, parent);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void register_native_date_time_picker(MyApplication* self,
                                             FlView* view,
                                             GtkWindow* window) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->native_date_time_picker_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      kNativeDateTimePickerChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->native_date_time_picker_channel,
      native_date_time_picker_method_call_cb, g_object_ref(window),
      g_object_unref);
}

static void respond_bool(FlMethodCall* method_call, gboolean value) {
  g_autoptr(FlValue) result = fl_value_new_bool(value);
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void respond_success(FlMethodCall* method_call) {
  g_autoptr(FlValue) result = fl_value_new_null();
  fl_method_call_respond_success(method_call, result, nullptr);
}

static gboolean fl_method_bool_arg(FlValue* args) {
  return args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL
             ? fl_value_get_bool(args)
             : FALSE;
}

static gdouble fl_method_double_arg(FlValue* args, gdouble fallback) {
  if (args == nullptr) {
    return fallback;
  }
  switch (fl_value_get_type(args)) {
    case FL_VALUE_TYPE_FLOAT:
      return fl_value_get_float(args);
    case FL_VALUE_TYPE_INT:
      return static_cast<gdouble>(fl_value_get_int(args));
    default:
      return fallback;
  }
}

static const gchar* fl_method_string_arg(FlValue* args) {
  return args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(args)
             : nullptr;
}

static void track_header_bar_pointer(MyApplication* self,
                                     GtkHeaderBar* header_bar) {
  self->header_bar = header_bar;
  g_object_add_weak_pointer(G_OBJECT(header_bar),
                            reinterpret_cast<gpointer*>(&self->header_bar));
}

static void track_widget_pointer(GtkWidget** target, GtkWidget* widget) {
  *target = widget;
  g_object_add_weak_pointer(G_OBJECT(widget),
                            reinterpret_cast<gpointer*>(target));
}

static gboolean has_header_bar(MyApplication* self) {
  return self->header_bar != nullptr && GTK_IS_HEADER_BAR(self->header_bar);
}

static gboolean is_css_hex_color(const gchar* value) {
  if (value == nullptr || strlen(value) != 7 || value[0] != '#') {
    return FALSE;
  }
  for (int i = 1; i < 7; i++) {
    if (!g_ascii_isxdigit(value[i])) {
      return FALSE;
    }
  }
  return TRUE;
}

static gboolean is_css_rgba_color(const gchar* value) {
  if (value == nullptr || !g_str_has_prefix(value, "rgba(")) {
    return FALSE;
  }
  gint red = -1;
  gint green = -1;
  gint blue = -1;
  gdouble alpha = -1;
  gchar extra = 0;
  if (sscanf(value, "rgba(%d,%d,%d,%lf)%c", &red, &green, &blue, &alpha,
             &extra) != 4) {
    return FALSE;
  }
  return red >= 0 && red <= 255 && green >= 0 && green <= 255 && blue >= 0 &&
         blue <= 255 && alpha >= 0 && alpha <= 1;
}

static gboolean is_css_color_token(const gchar* value) {
  return is_css_hex_color(value) || is_css_rgba_color(value);
}

static const gchar* css_color_or(const gchar* value, const gchar* fallback) {
  return is_css_color_token(value) ? value : fallback;
}

static void set_flutter_view_background_color(MyApplication* self,
                                              const gchar* color) {
  if (self->flutter_view == nullptr || !FL_IS_VIEW(self->flutter_view) ||
      !is_css_color_token(color)) {
    return;
  }

  GdkRGBA background_color;
  if (!gdk_rgba_parse(&background_color, color)) {
    return;
  }
  fl_view_set_background_color(FL_VIEW(self->flutter_view), &background_color);
}

static void set_flutter_view_background_transparent(MyApplication* self) {
  if (self->flutter_view == nullptr || !FL_IS_VIEW(self->flutter_view)) {
    return;
  }

  GdkRGBA transparent = {0, 0, 0, 0};
  fl_view_set_background_color(FL_VIEW(self->flutter_view), &transparent);
}

static void set_main_flutter_view_background(MyApplication* self) {
  if (self->main_window_transparent_backing) {
    set_flutter_view_background_transparent(self);
    return;
  }

  set_flutter_view_background_color(
      self, css_color_or(self->header_bar_window_background_color,
                         self->header_bar_background_color));
}

static gint header_sidebar_effective_width(MyApplication* self) {
  if (!self->header_bar_sidebar_visible) {
    return 0;
  }
  return self->header_bar_sidebar_width;
}

static void refresh_header_bar_css(MyApplication* self) {
  if (!has_header_bar(self) ||
      !is_css_color_token(self->header_bar_background_color)) {
    return;
  }

  const gchar* background_color = self->header_bar_background_color;
  const gchar* window_background_color =
      css_color_or(self->header_bar_window_background_color, background_color);
  const gchar* window_css_background_color =
      self->main_window_transparent_backing ? "transparent"
                                            : window_background_color;
  const gchar* sidebar_background_color =
      is_css_color_token(self->header_bar_sidebar_background_color)
          ? self->header_bar_sidebar_background_color
          : background_color;
  const gchar* foreground_color = css_color_or(
      self->header_bar_foreground_color, "rgba(255,255,255,0.86)");
  const gchar* foreground_disabled_color =
      css_color_or(self->header_bar_disabled_foreground_color,
                   "rgba(255,255,255,0.38)");
  const gchar* muted_foreground_color = css_color_or(
      self->header_bar_muted_foreground_color, "rgba(255,255,255,0.70)");
  const gchar* control_color =
      css_color_or(self->header_bar_control_color, "rgba(255,255,255,0.10)");
  const gchar* control_hover_color = css_color_or(
      self->header_bar_control_hover_color, "rgba(255,255,255,0.14)");
  const gchar* control_pressed_color = css_color_or(
      self->header_bar_control_active_color, "rgba(255,255,255,0.18)");
  const gchar* accent_color =
      css_color_or(self->header_bar_accent_color, control_pressed_color);
  const gchar* accent_foreground_color =
      css_color_or(self->header_bar_accent_foreground_color, foreground_color);
  const gchar* popover_background_color = css_color_or(
      self->header_bar_popover_background_color, background_color);
  const gchar* border_color =
      css_color_or(self->header_bar_border_color, "rgba(255,255,255,0.10)");
  const gchar* shade_color =
      css_color_or(self->header_bar_shade_color, "rgba(0,0,0,0.28)");
  const gchar* modal_barrier_color = css_color_or(
      self->header_bar_modal_barrier_color, "rgba(0,0,0,0.32)");
  GtkWidget* header_bar = GTK_WIDGET(self->header_bar);
  GtkStyleContext* context = gtk_widget_get_style_context(header_bar);
  gtk_style_context_add_class(context, "busymax-flat-headerbar");

  g_autofree gchar* css = g_strdup_printf(
      "window#busymax-window,"
      "window#busymax-window:backdrop {"
      "background-color: %s;"
      "background-image: none;"
      "}"
      "window#busymax-window decoration,"
      "window#busymax-window decoration:backdrop {"
      "background-color: transparent;"
      "background-image: none;"
      "border: none;"
      "box-shadow: 0 3px 18px 2px %s;"
      "outline: none;"
      "border-radius: %dpx;"
      "}"
      ".busymax-titlebar,"
      ".busymax-titlebar:backdrop,"
      "headerbar.busymax-flat-headerbar,"
      "headerbar.busymax-flat-headerbar:backdrop {"
      "background-color: %s;"
      "background-image: none;"
      "border: none;"
      "box-shadow: none;"
      "border-top-left-radius: %dpx;"
      "border-top-right-radius: %dpx;"
      "}"
      "headerbar.busymax-flat-headerbar,"
      "headerbar.busymax-flat-headerbar:backdrop {"
      "border-top-left-radius: 0;"
      "border-top-right-radius: %dpx;"
      "padding-left: 0;"
      "}"
      ".busymax-titlebar .busymax-header-brand {"
      "background-color: %s;"
      "background-image: none;"
      "border: none;"
      "box-shadow: none;"
      "border-top-left-radius: %dpx;"
      "border-top-right-radius: 0;"
      "}"
      ".busymax-titlebar .busymax-header-brand label {"
      "color: %s;"
      "}"
      ".busymax-titlebar .busymax-header-title {"
      "color: %s;"
      "}"
      ".busymax-titlebar.busymax-modal-barrier,"
      ".busymax-titlebar.busymax-modal-barrier:backdrop,"
      ".busymax-titlebar.busymax-modal-barrier .busymax-header-brand,"
      ".busymax-titlebar.busymax-modal-barrier "
      "headerbar.busymax-flat-headerbar {"
      "background-image: linear-gradient(%s, %s);"
      "}"
      ".busymax-titlebar button.busymax-header-button,"
      ".busymax-titlebar button.busymax-header-view-mode-button {"
      "color: %s;"
      "background-color: %s;"
      "background-image: none;"
      "border: none;"
      "border-width: 0;"
      "border-color: transparent;"
      "border-image: none;"
      "outline-color: transparent;"
      "outline-style: none;"
      "outline-width: 0;"
      "box-shadow: none;"
      "text-shadow: none;"
      "-gtk-icon-shadow: none;"
      "transition: none;"
      "min-height: %dpx;"
      "min-width: %dpx;"
      "padding: 0 %dpx;"
      "border-radius: %dpx;"
      "}"
      ".busymax-titlebar button.busymax-header-button:hover,"
      ".busymax-titlebar button.busymax-header-view-mode-button:hover {"
      "background-color: %s;"
      "}"
      ".busymax-titlebar button.busymax-header-button:active,"
      ".busymax-titlebar button.busymax-header-button:checked,"
      ".busymax-titlebar button.busymax-header-view-mode-button:checked,"
      ".busymax-titlebar button.busymax-header-view-mode-button:active {"
      "background-color: %s;"
      "}"
      ".busymax-titlebar button.busymax-header-button:disabled,"
      ".busymax-titlebar button.busymax-header-view-mode-button:disabled {"
      "color: %s;"
      "background-color: transparent;"
      "}"
      ".busymax-titlebar button.busymax-header-primary-button {"
      "color: %s;"
      "background-color: %s;"
      "}"
      ".busymax-titlebar button.busymax-header-primary-button:hover,"
      ".busymax-titlebar button.busymax-header-primary-button:active,"
      ".busymax-titlebar button.busymax-header-primary-button:checked {"
      "color: %s;"
      "background-color: %s;"
      "}"
      ".busymax-titlebar button.busymax-header-primary-button:disabled {"
      "color: %s;"
      "background-color: transparent;"
      "}"
      ".busymax-titlebar .busymax-header-brand "
      "button.busymax-brand-action-button,"
      ".busymax-titlebar .busymax-header-brand "
      "button.busymax-brand-action-button:checked,"
      ".busymax-titlebar .busymax-header-brand "
      "button.busymax-brand-action-button:active {"
      "background-color: transparent;"
      "}"
      ".busymax-titlebar .busymax-header-brand "
      "button.busymax-brand-action-button:hover {"
      "background-color: %s;"
      "}"
      ".busymax-titlebar button.busymax-header-button.busymax-sidebar-toggle,"
      ".busymax-titlebar button.busymax-header-button.busymax-sidebar-toggle:checked,"
      ".busymax-titlebar button.busymax-header-button.busymax-sidebar-toggle:active {"
      "background-color: transparent;"
      "}"
      ".busymax-titlebar button.busymax-header-button.busymax-sidebar-toggle:hover {"
      "background-color: %s;"
      "}"
      ".busymax-titlebar.busymax-modal-barrier label,"
      ".busymax-titlebar.busymax-modal-barrier button,"
      ".busymax-titlebar.busymax-modal-barrier button image {"
      "color: %s;"
      "text-shadow: none;"
      "-gtk-icon-shadow: none;"
      "}"
      ".busymax-titlebar button.busymax-header-icon-button {"
      "min-width: %dpx;"
      "padding-left: 0;"
      "padding-right: 0;"
      "}"
      "popover.busymax-header-popover,"
      "popover.background.busymax-header-popover,"
      ".busymax-header-popover.background,"
      "popover.busymax-header-popover:backdrop,"
      "popover.background.busymax-header-popover:backdrop,"
      ".busymax-header-popover.background:backdrop,"
      "popover.background.busymax-header-popover > contents,"
      ".busymax-header-popover.background > contents,"
      "popover.background.busymax-header-popover arrow,"
      ".busymax-header-popover.background arrow {"
      "background-color: %s;"
      "color: %s;"
      "}"
      "popover.busymax-header-popover > contents,"
      ".busymax-header-popover.background > contents {"
      "border: 1px solid %s;"
      "box-shadow: 0 6px 18px %s;"
      "}"
      "popover.busymax-header-popover button.busymax-header-popover-row {"
      "color: %s;"
      "background-color: transparent;"
      "background-image: none;"
      "border: none;"
      "border-width: 0;"
      "border-color: transparent;"
      "border-image: none;"
      "outline-color: transparent;"
      "outline-style: none;"
      "outline-width: 0;"
      "outline-offset: 0;"
      "box-shadow: none;"
      "text-shadow: none;"
      "-gtk-icon-shadow: none;"
      "transition: none;"
      "min-height: %dpx;"
      "padding: 0 %dpx;"
      "border-radius: %dpx;"
      "}"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row:hover {"
      "background-color: %s;"
      "}"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row:focus {"
      "border-color: transparent;"
      "outline-color: transparent;"
      "outline-style: none;"
      "outline-width: 0;"
      "box-shadow: none;"
      "}"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row:active,"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row:checked {"
      "background-color: transparent;"
      "}"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row label {"
      "color: %s;"
      "}"
      "popover.busymax-header-popover "
      "button.busymax-header-popover-row image {"
      "color: %s;"
      "}"
      "tooltip,"
      "tooltip.background {"
      "margin: 0;"
      "padding: 0;"
      "min-height: 0;"
      "border-radius: %dpx;"
      "box-shadow: 0 5px 18px 2px %s;"
      "}"
      "tooltip > box,"
      "tooltip.background > box {"
      "margin: 0;"
      "padding: 0;"
      "min-height: 0;"
      "}"
      "tooltip label {"
      "margin: 0;"
      "padding: %dpx %dpx;"
      "min-height: 0;"
      "border-radius: %dpx;"
      "}",
      window_css_background_color, shade_color, kHeaderWindowRadius,
      background_color, kHeaderWindowRadius, kHeaderWindowRadius,
      kHeaderWindowRadius, sidebar_background_color, kHeaderWindowRadius,
      foreground_color, foreground_color, modal_barrier_color,
      modal_barrier_color,
      foreground_color, control_color, kHeaderButtonHeight,
      kHeaderButtonHeight, kHeaderButtonHorizontalPadding, kHeaderButtonRadius,
      control_hover_color, control_pressed_color, foreground_disabled_color,
      accent_foreground_color, accent_color, accent_foreground_color,
      accent_color, foreground_disabled_color,
      control_hover_color, control_hover_color, foreground_disabled_color,
      kHeaderButtonHeight,
      popover_background_color, foreground_color, foreground_color,
      border_color, shade_color, kHeaderButtonHeight,
      kHeaderButtonHorizontalPadding, kHeaderButtonRadius,
      control_hover_color, foreground_color, muted_foreground_color,
      kHeaderButtonRadius, shade_color, kHeaderTooltipVerticalPadding,
      kHeaderTooltipHorizontalPadding, kHeaderButtonRadius);

  g_autoptr(GError) error = nullptr;
  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(provider, css, -1, &error);
  if (error != nullptr) {
    g_warning("Failed to load headerbar CSS: %s", error->message);
    g_object_unref(provider);
    return;
  }

  GdkScreen* screen = gtk_widget_get_screen(header_bar);
  if (self->header_bar_css_provider != nullptr) {
    gtk_style_context_remove_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(self->header_bar_css_provider));
    g_clear_object(&self->header_bar_css_provider);
  }
  self->header_bar_css_provider = provider;
  gtk_style_context_add_provider_for_screen(
      screen, GTK_STYLE_PROVIDER(self->header_bar_css_provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

static void set_css_color_field(gchar** target, const gchar* value) {
  if (!is_css_color_token(value)) {
    return;
  }
  g_free(*target);
  *target = g_strdup(value);
}

static void set_header_bar_theme(MyApplication* self, FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return;
  }
  set_css_color_field(&self->header_bar_window_background_color,
                      fl_lookup_string_arg(args, "windowBackgroundColor"));
  set_css_color_field(&self->header_bar_background_color,
                      fl_lookup_string_arg(args, "backgroundColor"));
  set_css_color_field(&self->header_bar_sidebar_background_color,
                      fl_lookup_string_arg(args, "sidebarBackgroundColor"));
  set_css_color_field(&self->header_bar_foreground_color,
                      fl_lookup_string_arg(args, "foregroundColor"));
  set_css_color_field(&self->header_bar_muted_foreground_color,
                      fl_lookup_string_arg(args, "mutedForegroundColor"));
  set_css_color_field(&self->header_bar_disabled_foreground_color,
                      fl_lookup_string_arg(args, "disabledForegroundColor"));
  set_css_color_field(&self->header_bar_control_color,
                      fl_lookup_string_arg(args, "controlColor"));
  set_css_color_field(&self->header_bar_control_hover_color,
                      fl_lookup_string_arg(args, "controlHoverColor"));
  set_css_color_field(&self->header_bar_control_active_color,
                      fl_lookup_string_arg(args, "controlActiveColor"));
  set_css_color_field(&self->header_bar_accent_color,
                      fl_lookup_string_arg(args, "accentColor"));
  set_css_color_field(&self->header_bar_accent_foreground_color,
                      fl_lookup_string_arg(args, "accentForegroundColor"));
  set_css_color_field(&self->header_bar_popover_background_color,
                      fl_lookup_string_arg(args, "popoverBackgroundColor"));
  set_css_color_field(&self->header_bar_border_color,
                      fl_lookup_string_arg(args, "borderColor"));
  set_css_color_field(&self->header_bar_shade_color,
                      fl_lookup_string_arg(args, "shadeColor"));
  set_css_color_field(&self->header_bar_modal_barrier_color,
                      fl_lookup_string_arg(args, "modalBarrierColor"));
  set_main_flutter_view_background(self);
  refresh_header_bar_css(self);
}

static void set_header_bar_modal_barrier_visible(MyApplication* self,
                                                 gboolean visible) {
  self->header_bar_modal_barrier_visible = visible;
  if (self->titlebar_box != nullptr && GTK_IS_WIDGET(self->titlebar_box)) {
    GtkStyleContext* context = gtk_widget_get_style_context(self->titlebar_box);
    if (visible) {
      gtk_style_context_add_class(context, "busymax-modal-barrier");
    } else {
      gtk_style_context_remove_class(context, "busymax-modal-barrier");
    }
    gtk_widget_set_sensitive(self->titlebar_box, !visible);
  }
}

static void clear_header_bar_pointer(MyApplication* self) {
  if (self->header_bar != nullptr) {
    g_object_remove_weak_pointer(
        G_OBJECT(self->header_bar),
        reinterpret_cast<gpointer*>(&self->header_bar));
    self->header_bar = nullptr;
  }
}

static void clear_widget_pointer(GtkWidget** target) {
  if (*target != nullptr) {
    g_object_remove_weak_pointer(G_OBJECT(*target),
                                 reinterpret_cast<gpointer*>(target));
    *target = nullptr;
  }
}

static void invoke_header_bar_action(MyApplication* self,
                                     const gchar* action) {
  if (self->header_bar_channel == nullptr || action == nullptr) {
    return;
  }
  fl_method_channel_invoke_method(self->header_bar_channel, action, nullptr,
                                  nullptr, nullptr, nullptr);
}

static void focus_flutter_view(MyApplication* self) {
  if (self->flutter_view != nullptr && GTK_IS_WIDGET(self->flutter_view)) {
    gtk_widget_grab_focus(self->flutter_view);
  }
}

static void header_bar_action_clicked_cb(GtkWidget* widget,
                                         gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->suppress_header_bar_actions) {
    return;
  }
  const gchar* action = static_cast<const gchar*>(
      g_object_get_data(G_OBJECT(widget), "busymax-header-action"));
  focus_flutter_view(self);
  invoke_header_bar_action(self, action);
}

static void connect_header_bar_action(MyApplication* self,
                                      GtkWidget* widget,
                                      const gchar* action) {
  g_object_set_data(G_OBJECT(widget), "busymax-header-action",
                    const_cast<gchar*>(action));
  g_signal_connect(widget, "clicked", G_CALLBACK(header_bar_action_clicked_cb),
                   self);
}

static void close_header_menu_button(GtkWidget* menu_button) {
  if (menu_button == nullptr || !GTK_IS_MENU_BUTTON(menu_button)) {
    return;
  }
  GtkPopover* popover = gtk_menu_button_get_popover(GTK_MENU_BUTTON(menu_button));
  if (popover != nullptr && GTK_IS_POPOVER(popover)) {
    gtk_popover_popdown(popover);
  }
  if (GTK_IS_TOGGLE_BUTTON(menu_button)) {
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(menu_button), FALSE);
  }
}

static GtkWidget* create_header_popup_window(MyApplication* self) {
  GtkWidget* popover = gtk_popover_new(nullptr);
  gtk_popover_set_position(GTK_POPOVER(popover), GTK_POS_BOTTOM);
  gtk_popover_set_modal(GTK_POPOVER(popover), TRUE);
  gtk_style_context_add_class(gtk_widget_get_style_context(popover),
                              "busymax-header-popover");
  g_object_set_data(G_OBJECT(popover), "busymax-application", self);
  return popover;
}

static GtkWidget* create_header_popover_box(GtkWidget* popover) {
  GtkWidget* box =
      gtk_box_new(GTK_ORIENTATION_VERTICAL, kHeaderPopoverRowSpacing);
  gtk_widget_set_margin_top(box, kHeaderMenuPadding);
  gtk_widget_set_margin_bottom(box, kHeaderMenuPadding);
  gtk_widget_set_margin_start(box, kHeaderMenuPadding);
  gtk_widget_set_margin_end(box, kHeaderMenuPadding);
  gtk_container_add(GTK_CONTAINER(popover), box);
  return box;
}

static void show_header_popover_content(GtkWidget* box) {
  if (box != nullptr && GTK_IS_WIDGET(box)) {
    gtk_widget_show_all(box);
  }
}

static void make_header_icon_button_square(GtkWidget* button) {
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              "busymax-header-icon-button");
  gtk_widget_set_size_request(button, kHeaderButtonHeight,
                              kHeaderButtonHeight);
  gtk_widget_set_valign(button, GTK_ALIGN_CENTER);
}

static GtkWidget* create_header_icon_button(const gchar* icon_name,
                                            const gchar* tooltip) {
  GtkWidget* button = gtk_button_new();
  GtkWidget* image = gtk_image_new_from_icon_name(icon_name, GTK_ICON_SIZE_MENU);
  gtk_button_set_image(GTK_BUTTON(button), image);
  gtk_button_set_relief(GTK_BUTTON(button), GTK_RELIEF_NONE);
  gtk_widget_set_tooltip_text(button, tooltip);
  gtk_widget_set_valign(button, GTK_ALIGN_CENTER);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              "busymax-header-button");
  make_header_icon_button_square(button);
  return button;
}

static GtkWidget* create_header_toggle_icon_button(const gchar* icon_name,
                                                   const gchar* tooltip) {
  GtkWidget* button = gtk_toggle_button_new();
  GtkWidget* image = gtk_image_new_from_icon_name(icon_name, GTK_ICON_SIZE_MENU);
  gtk_button_set_image(GTK_BUTTON(button), image);
  gtk_button_set_relief(GTK_BUTTON(button), GTK_RELIEF_NONE);
  gtk_widget_set_tooltip_text(button, tooltip);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              "busymax-header-button");
  make_header_icon_button_square(button);
  return button;
}

static GtkWidget* create_header_text_button(const gchar* label,
                                            const gchar* tooltip) {
  GtkWidget* button = gtk_button_new_with_label(label);
  gtk_button_set_relief(GTK_BUTTON(button), GTK_RELIEF_NONE);
  gtk_widget_set_tooltip_text(button, tooltip);
  gtk_widget_set_valign(button, GTK_ALIGN_CENTER);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(button),
                              "busymax-header-button");
  return button;
}

static void set_button_label_and_tooltip(GtkWidget* button,
                                         const gchar* label,
                                         const gchar* tooltip) {
  if (button == nullptr || !GTK_IS_BUTTON(button)) {
    return;
  }
  if (label != nullptr) {
    gtk_button_set_label(GTK_BUTTON(button), label);
  }
  if (tooltip != nullptr) {
    gtk_widget_set_tooltip_text(button, tooltip);
  }
}

static void set_widget_tooltip(GtkWidget* widget, const gchar* tooltip) {
  if (widget != nullptr && GTK_IS_WIDGET(widget) && tooltip != nullptr) {
    gtk_widget_set_tooltip_text(widget, tooltip);
  }
}

static void set_toggle_button_active(MyApplication* self,
                                     GtkWidget* button,
                                     gboolean active) {
  if (button != nullptr && GTK_IS_TOGGLE_BUTTON(button)) {
    const gboolean previous_suppression = self->suppress_header_bar_actions;
    self->suppress_header_bar_actions = TRUE;
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(button), active);
    self->suppress_header_bar_actions = previous_suppression;
  }
}

static void set_widget_sensitive(GtkWidget* widget, gboolean sensitive) {
  if (widget != nullptr && GTK_IS_WIDGET(widget)) {
    gtk_widget_set_sensitive(widget, sensitive);
  }
}

static void set_widget_visible(GtkWidget* widget, gboolean visible) {
  if (widget != nullptr && GTK_IS_WIDGET(widget)) {
    gtk_widget_set_visible(widget, visible);
  }
}

static void update_header_sidebar_brand_geometry(MyApplication* self) {
  if (self->header_sidebar_brand_box == nullptr ||
      !GTK_IS_WIDGET(self->header_sidebar_brand_box)) {
    return;
  }
  const gint width = header_sidebar_effective_width(self);
  gtk_widget_set_size_request(self->header_sidebar_brand_box, width, -1);
  set_widget_visible(self->header_sidebar_brand_box, width > 0);
}

static const gchar* header_view_mode_action(const gchar* mode) {
  if (g_strcmp0(mode, "day") == 0) {
    return "viewModeDay";
  }
  if (g_strcmp0(mode, "week") == 0) {
    return "viewModeWeek";
  }
  if (g_strcmp0(mode, "month") == 0) {
    return "viewModeMonth";
  }
  if (g_strcmp0(mode, "year") == 0) {
    return "viewModeYear";
  }
  if (g_strcmp0(mode, "agenda") == 0) {
    return "viewModeAgenda";
  }
  return nullptr;
}

static void set_header_view_mode(MyApplication* self, const gchar* mode);

static GtkWidget* header_view_mode_item(MyApplication* self,
                                        const gchar* mode) {
  if (g_strcmp0(mode, "day") == 0) {
    return self->view_mode_day_item;
  }
  if (g_strcmp0(mode, "week") == 0) {
    return self->view_mode_week_item;
  }
  if (g_strcmp0(mode, "month") == 0) {
    return self->view_mode_month_item;
  }
  if (g_strcmp0(mode, "year") == 0) {
    return self->view_mode_year_item;
  }
  if (g_strcmp0(mode, "agenda") == 0) {
    return self->view_mode_agenda_item;
  }
  return nullptr;
}

static void set_header_view_mode_item_label(GtkWidget* item,
                                            const gchar* label) {
  if (item == nullptr || label == nullptr) {
    return;
  }
  g_object_set_data_full(G_OBJECT(item), "busymax-header-label",
                         g_strdup(label), g_free);
  GtkWidget* label_widget = static_cast<GtkWidget*>(
      g_object_get_data(G_OBJECT(item), "busymax-header-label-widget"));
  if (label_widget != nullptr && GTK_IS_LABEL(label_widget)) {
    gtk_label_set_text(GTK_LABEL(label_widget), label);
    return;
  }
  if (GTK_IS_BUTTON(item)) {
    gtk_button_set_label(GTK_BUTTON(item), label);
  }
}

static void set_header_view_mode_item_active(MyApplication* self,
                                             GtkWidget* item,
                                             gboolean active) {
  if (item == nullptr || !GTK_IS_WIDGET(item)) {
    return;
  }
  GtkWidget* check_widget = static_cast<GtkWidget*>(
      g_object_get_data(G_OBJECT(item), "busymax-header-check-widget"));
  if (check_widget != nullptr && GTK_IS_WIDGET(check_widget)) {
    gtk_widget_set_opacity(check_widget, active ? 1.0 : 0.0);
  }
}

static const gchar* header_view_mode_item_label(GtkWidget* item) {
  if (item == nullptr) {
    return "";
  }
  const gchar* stored_label = static_cast<const gchar*>(
      g_object_get_data(G_OBJECT(item), "busymax-header-label"));
  if (stored_label != nullptr) {
    return stored_label;
  }
  const gchar* label = nullptr;
  if (GTK_IS_BUTTON(item)) {
    label = gtk_button_get_label(GTK_BUTTON(item));
  }
  return label != nullptr ? label : "";
}

static void update_header_view_mode_label(MyApplication* self) {
  if (self->view_mode_label == nullptr ||
      !GTK_IS_LABEL(self->view_mode_label)) {
    return;
  }
  const gchar* mode =
      self->header_view_mode != nullptr ? self->header_view_mode : "week";
  const gchar* label = header_view_mode_item_label(
      header_view_mode_item(self, mode));
  gtk_label_set_text(GTK_LABEL(self->view_mode_label), label);
}

static void update_header_view_mode_items(MyApplication* self) {
  const gchar* mode =
      self->header_view_mode != nullptr ? self->header_view_mode : "week";
  set_header_view_mode_item_active(self, self->view_mode_day_item,
                                   g_strcmp0(mode, "day") == 0);
  set_header_view_mode_item_active(self, self->view_mode_week_item,
                                   g_strcmp0(mode, "week") == 0);
  set_header_view_mode_item_active(self, self->view_mode_month_item,
                                   g_strcmp0(mode, "month") == 0);
  set_header_view_mode_item_active(self, self->view_mode_year_item,
                                   g_strcmp0(mode, "year") == 0);
  set_header_view_mode_item_active(self, self->view_mode_agenda_item,
                                   g_strcmp0(mode, "agenda") == 0);
}

static void header_view_mode_item_clicked_cb(GtkWidget* widget,
                                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->suppress_header_bar_actions) {
    return;
  }
  const gchar* mode = static_cast<const gchar*>(
      g_object_get_data(G_OBJECT(widget), "busymax-view-mode"));
  if (header_view_mode_action(mode) == nullptr) {
    return;
  }
  set_header_view_mode(self, mode);
  close_header_menu_button(self->view_mode_button);
  focus_flutter_view(self);
  invoke_header_bar_action(self, header_view_mode_action(mode));
}

static GtkWidget* create_header_view_mode_item(MyApplication* self,
                                               const gchar* mode,
                                               const gchar* fallback_label) {
  GtkWidget* item = gtk_button_new();
  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, kHeaderButtonSpacing);
  GtkWidget* check =
      gtk_image_new_from_icon_name("object-select-symbolic", GTK_ICON_SIZE_MENU);
  GtkWidget* label = gtk_label_new(fallback_label);
  gtk_label_set_xalign(GTK_LABEL(label), 0.0);
  gtk_widget_set_hexpand(label, TRUE);
  gtk_box_pack_start(GTK_BOX(box), check, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(box), label, TRUE, TRUE, 0);
  gtk_container_add(GTK_CONTAINER(item), box);
  gtk_widget_set_opacity(check, 0.0);
  gtk_button_set_relief(GTK_BUTTON(item), GTK_RELIEF_NONE);
  gtk_widget_set_halign(item, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(item, TRUE);
  gtk_style_context_add_class(gtk_widget_get_style_context(item),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(item),
                              "busymax-header-popover-row");
  g_object_set_data(G_OBJECT(item), "busymax-header-label-widget", label);
  g_object_set_data(G_OBJECT(item), "busymax-header-check-widget", check);
  g_object_set_data_full(G_OBJECT(item), "busymax-header-label",
                         g_strdup(fallback_label), g_free);
  g_object_set_data_full(G_OBJECT(item), "busymax-view-mode",
                         g_strdup(mode), g_free);
  g_signal_connect(item, "clicked",
                   G_CALLBACK(header_view_mode_item_clicked_cb), self);
  return item;
}

static void header_settings_item_clicked_cb(GtkWidget* widget,
                                            gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->suppress_header_bar_actions) {
    return;
  }
  const gchar* action = static_cast<const gchar*>(
      g_object_get_data(G_OBJECT(widget), "busymax-settings-action"));
  close_header_menu_button(self->settings_menu_button);
  focus_flutter_view(self);
  invoke_header_bar_action(self, action);
}

static GtkWidget* create_header_settings_item(MyApplication* self,
                                              const gchar* action,
                                              const gchar* fallback_label) {
  GtkWidget* item = gtk_button_new();
  GtkWidget* label = gtk_label_new(fallback_label);
  gtk_label_set_xalign(GTK_LABEL(label), 0.0);
  gtk_widget_set_hexpand(label, TRUE);
  gtk_container_add(GTK_CONTAINER(item), label);
  gtk_button_set_relief(GTK_BUTTON(item), GTK_RELIEF_NONE);
  gtk_widget_set_halign(item, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(item, TRUE);
  gtk_style_context_add_class(gtk_widget_get_style_context(item),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(item),
                              "busymax-header-popover-row");
  g_object_set_data(G_OBJECT(item), "busymax-header-label-widget", label);
  g_object_set_data_full(G_OBJECT(item), "busymax-header-label",
                         g_strdup(fallback_label), g_free);
  g_object_set_data_full(G_OBJECT(item), "busymax-settings-action",
                         g_strdup(action), g_free);
  g_signal_connect(item, "clicked",
                   G_CALLBACK(header_settings_item_clicked_cb), self);
  return item;
}

static void set_header_settings_item_label(GtkWidget* item,
                                           const gchar* label) {
  if (item == nullptr || label == nullptr) {
    return;
  }
  GtkWidget* label_widget = static_cast<GtkWidget*>(
      g_object_get_data(G_OBJECT(item), "busymax-header-label-widget"));
  if (label_widget != nullptr && GTK_IS_LABEL(label_widget)) {
    gtk_label_set_text(GTK_LABEL(label_widget), label);
    return;
  }
  if (GTK_IS_BUTTON(item)) {
    gtk_button_set_label(GTK_BUTTON(item), label);
  }
}

static void set_header_view_mode_labels(MyApplication* self,
                                        const gchar* day,
                                        const gchar* week,
                                        const gchar* month,
                                        const gchar* year,
                                        const gchar* agenda) {
  set_header_view_mode_item_label(self->view_mode_day_item, day);
  set_header_view_mode_item_label(self->view_mode_week_item, week);
  set_header_view_mode_item_label(self->view_mode_month_item, month);
  set_header_view_mode_item_label(self->view_mode_year_item, year);
  set_header_view_mode_item_label(self->view_mode_agenda_item, agenda);
  update_header_view_mode_label(self);
}

static void set_header_view_mode(MyApplication* self, const gchar* mode) {
  if (header_view_mode_action(mode) == nullptr) {
    return;
  }
  if (g_strcmp0(self->header_view_mode, mode) != 0) {
    g_free(self->header_view_mode);
    self->header_view_mode = g_strdup(mode);
  }
  update_header_view_mode_label(self);
  update_header_view_mode_items(self);
}

static void update_header_title_balance_spacer(MyApplication* self) {
  if (self->header_title_balance_spacer == nullptr ||
      !GTK_IS_WIDGET(self->header_title_balance_spacer)) {
    return;
  }
  const gboolean visible =
      !self->header_schedule_controls_visible && !self->header_back_visible;
  gtk_widget_set_size_request(self->header_title_balance_spacer,
                              kHeaderWindowControlsBalanceWidth, -1);
  set_widget_visible(self->header_title_balance_spacer, visible);
}

static void update_header_title_box_geometry(MyApplication* self) {
  if (self->header_title_box == nullptr ||
      !GTK_IS_WIDGET(self->header_title_box)) {
    return;
  }
  const gint width = self->header_onboarding_controls_visible
                         ? kHeaderOnboardingContentWidth
                         : -1;
  gtk_widget_set_size_request(self->header_title_box, width, -1);
}

static void set_header_schedule_controls_visible(MyApplication* self,
                                                 gboolean visible) {
  self->header_schedule_controls_visible = visible;
  set_widget_visible(self->header_start_box,
                     visible || self->header_back_visible);
  set_widget_visible(self->sidebar_collapsed_toggle_button, visible);
  set_widget_visible(self->today_button, visible);
  set_widget_visible(self->previous_button,
                     visible && self->header_navigation_visible);
  set_widget_visible(self->next_button,
                     visible && self->header_navigation_visible);
  set_widget_visible(self->header_view_box, visible);
  set_widget_visible(self->search_button, visible);
  set_widget_visible(self->refresh_button, visible);
  update_header_title_balance_spacer(self);
}

static void set_header_navigation_visible(MyApplication* self,
                                          gboolean visible) {
  self->header_navigation_visible = visible;
  set_widget_visible(self->previous_button,
                     self->header_schedule_controls_visible && visible);
  set_widget_visible(self->next_button,
                     self->header_schedule_controls_visible && visible);
}

static void set_header_back_visible(MyApplication* self, gboolean visible) {
  self->header_back_visible = visible;
  set_widget_visible(self->back_button, visible);
  set_widget_visible(self->header_start_box,
                     visible || self->header_schedule_controls_visible);
  update_header_title_balance_spacer(self);
}

static void set_header_onboarding_controls(MyApplication* self, FlValue* args) {
  const gboolean visible = fl_lookup_bool_arg(args, "visible", FALSE);
  const gboolean can_go_back = fl_lookup_bool_arg(args, "canGoBack", FALSE);
  const gboolean can_continue =
      fl_lookup_bool_arg(args, "canContinue", FALSE);
  const gchar* back_label = fl_lookup_string_arg(args, "backLabel");
  const gchar* continue_label = fl_lookup_string_arg(args, "continueLabel");

  self->header_onboarding_controls_visible = visible;
  set_widget_visible(self->onboarding_back_slot, visible);
  set_widget_visible(self->onboarding_back_button, visible);
  set_widget_visible(self->onboarding_continue_slot, visible);
  set_widget_visible(self->onboarding_continue_button, visible);
  set_widget_sensitive(self->onboarding_back_button, can_go_back);
  set_widget_sensitive(self->onboarding_continue_button, can_continue);
  set_button_label_and_tooltip(self->onboarding_back_button, back_label,
                               back_label);
  set_button_label_and_tooltip(self->onboarding_continue_button,
                               continue_label, continue_label);
  update_header_title_box_geometry(self);
  update_header_title_balance_spacer(self);
}

static void set_header_sidebar_visible(MyApplication* self, gboolean visible) {
  self->header_bar_sidebar_visible = visible;
  set_widget_visible(self->sidebar_collapsed_toggle_button,
                     self->header_schedule_controls_visible);
  set_toggle_button_active(self, self->sidebar_collapsed_toggle_button, visible);
  update_header_sidebar_brand_geometry(self);
  refresh_header_bar_css(self);
}

static void set_header_sidebar_width(MyApplication* self, gdouble width) {
  if (width <= 0) {
    return;
  }
  self->header_bar_sidebar_width = static_cast<gint>(width);
  update_header_sidebar_brand_geometry(self);
  refresh_header_bar_css(self);
}

static void set_header_localized_labels(MyApplication* self, FlValue* args) {
  const gchar* today = fl_lookup_string_arg(args, "today");
  const gchar* day = fl_lookup_string_arg(args, "day");
  const gchar* week = fl_lookup_string_arg(args, "week");
  const gchar* month = fl_lookup_string_arg(args, "month");
  const gchar* year = fl_lookup_string_arg(args, "year");
  const gchar* agenda = fl_lookup_string_arg(args, "agenda");
  const gchar* search = fl_lookup_string_arg(args, "search");
  const gchar* refresh = fl_lookup_string_arg(args, "refresh");
  const gchar* menu = fl_lookup_string_arg(args, "menu");
  const gchar* previous = fl_lookup_string_arg(args, "previous");
  const gchar* next = fl_lookup_string_arg(args, "next");
  const gchar* sidebar = fl_lookup_string_arg(args, "sidebar");
  const gchar* back = fl_lookup_string_arg(args, "back");
  const gchar* settings = fl_lookup_string_arg(args, "settings");
  const gchar* about_busymax = fl_lookup_string_arg(args, "aboutBusyMax");

  set_button_label_and_tooltip(self->today_button, today, today);
  set_header_view_mode_labels(self, day, week, month, year, agenda);
  set_widget_tooltip(self->back_button, back);
  set_widget_tooltip(self->search_button, search);
  set_widget_tooltip(self->settings_menu_button, menu);
  set_widget_tooltip(self->refresh_button, refresh);
  set_widget_tooltip(self->previous_button, previous);
  set_widget_tooltip(self->next_button, next);
  set_widget_tooltip(self->sidebar_collapsed_toggle_button, sidebar);
  set_header_settings_item_label(self->settings_item, settings);
  set_header_settings_item_label(self->about_item, about_busymax);
}

static GtkWidget* create_busymax_header_bar(MyApplication* self) {
  track_widget_pointer(&self->titlebar_box,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0));
  gtk_widget_set_halign(self->titlebar_box, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(self->titlebar_box, TRUE);
  gtk_style_context_add_class(gtk_widget_get_style_context(self->titlebar_box),
                              "busymax-titlebar");

  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  track_header_bar_pointer(self, header_bar);
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_widget_set_hexpand(GTK_WIDGET(header_bar), TRUE);

  track_widget_pointer(&self->header_sidebar_brand_box,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL,
                                   kHeaderButtonSpacing));
  gtk_widget_set_halign(self->header_sidebar_brand_box, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(self->header_sidebar_brand_box, FALSE);
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->header_sidebar_brand_box),
      "busymax-header-brand");
  track_widget_pointer(
      &self->search_button,
      create_header_toggle_icon_button("system-search-symbolic", ""));
  gtk_style_context_add_class(gtk_widget_get_style_context(self->search_button),
                              "busymax-brand-action-button");
  gtk_widget_set_margin_start(self->search_button,
                              kHeaderSidebarContentInset);
  connect_header_bar_action(self, self->search_button, "search");

  GtkWidget* brand_center_box =
      gtk_box_new(GTK_ORIENTATION_HORIZONTAL, kHeaderButtonSpacing);
  gtk_widget_set_halign(brand_center_box, GTK_ALIGN_CENTER);
  gtk_widget_set_valign(brand_center_box, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand(brand_center_box, TRUE);
  track_widget_pointer(&self->header_brand_label,
                       gtk_label_new(kApplicationDisplayName));
  gtk_widget_set_valign(self->header_brand_label, GTK_ALIGN_CENTER);
  gtk_label_set_ellipsize(GTK_LABEL(self->header_brand_label),
                          PANGO_ELLIPSIZE_END);
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->header_brand_label),
      GTK_STYLE_CLASS_TITLE);
  gtk_box_pack_start(GTK_BOX(brand_center_box), self->header_brand_label,
                     FALSE, FALSE, 0);

  track_widget_pointer(&self->settings_menu, create_header_popup_window(self));
  GtkWidget* settings_menu_box = create_header_popover_box(self->settings_menu);

  track_widget_pointer(&self->settings_item,
                       create_header_settings_item(self, "settings",
                                                   "Settings"));
  track_widget_pointer(&self->about_item,
                       create_header_settings_item(self, "aboutBusyMax",
                                                   "About BusyMax"));
  gtk_box_pack_start(GTK_BOX(settings_menu_box), self->settings_item, FALSE,
                     FALSE, 0);
  gtk_box_pack_start(GTK_BOX(settings_menu_box), self->about_item, FALSE,
                     FALSE, 0);
  show_header_popover_content(settings_menu_box);

  track_widget_pointer(&self->settings_menu_button, gtk_menu_button_new());
  gtk_button_set_relief(GTK_BUTTON(self->settings_menu_button),
                        GTK_RELIEF_NONE);
  gtk_button_set_image(GTK_BUTTON(self->settings_menu_button),
                       gtk_image_new_from_icon_name("open-menu-symbolic",
                                                    GTK_ICON_SIZE_MENU));
  gtk_menu_button_set_use_popover(GTK_MENU_BUTTON(self->settings_menu_button),
                                  TRUE);
  gtk_menu_button_set_popover(GTK_MENU_BUTTON(self->settings_menu_button),
                              self->settings_menu);
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->settings_menu_button),
      GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->settings_menu_button),
      "busymax-header-button");
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->settings_menu_button),
      "busymax-brand-action-button");
  make_header_icon_button_square(self->settings_menu_button);
  gtk_widget_set_margin_end(self->settings_menu_button,
                            kHeaderSidebarContentInset);

  gtk_box_pack_start(GTK_BOX(self->header_sidebar_brand_box),
                     self->search_button, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_sidebar_brand_box),
                     brand_center_box, TRUE, TRUE, 0);
  gtk_box_pack_end(GTK_BOX(self->header_sidebar_brand_box),
                   self->settings_menu_button, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->titlebar_box),
                     self->header_sidebar_brand_box, FALSE, FALSE, 0);

  track_widget_pointer(&self->header_title_balance_spacer,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0));
  gtk_widget_set_size_request(self->header_title_balance_spacer,
                              kHeaderWindowControlsBalanceWidth, -1);
  gtk_widget_set_visible(self->header_title_balance_spacer, FALSE);
  gtk_header_bar_pack_start(header_bar, self->header_title_balance_spacer);

  track_widget_pointer(&self->header_start_box,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL,
                                   kHeaderButtonSpacing));
  gtk_widget_set_margin_start(self->header_start_box,
                              kHeaderMainContentStartInset);
  track_widget_pointer(&self->back_button,
                       create_header_icon_button("go-previous-symbolic", ""));
  track_widget_pointer(
      &self->sidebar_collapsed_toggle_button,
      create_header_toggle_icon_button("sidebar-show-symbolic", ""));
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->sidebar_collapsed_toggle_button),
      "busymax-sidebar-toggle");
  track_widget_pointer(&self->today_button,
                       create_header_text_button("", ""));
  track_widget_pointer(&self->previous_button,
                       create_header_icon_button("go-previous-symbolic",
                                                 ""));
  track_widget_pointer(&self->next_button,
                       create_header_icon_button("go-next-symbolic", ""));
  connect_header_bar_action(self, self->back_button, "back");
  connect_header_bar_action(self, self->sidebar_collapsed_toggle_button,
                            "sidebarToggle");
  connect_header_bar_action(self, self->today_button, "today");
  connect_header_bar_action(self, self->previous_button, "previous");
  connect_header_bar_action(self, self->next_button, "next");
  gtk_box_pack_start(GTK_BOX(self->header_start_box), self->back_button,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_start_box),
                     self->sidebar_collapsed_toggle_button, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_start_box), self->today_button,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_start_box), self->previous_button,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_start_box), self->next_button,
                     FALSE, FALSE, 0);
  gtk_header_bar_pack_start(header_bar, self->header_start_box);

  track_widget_pointer(&self->header_title_box,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL,
                                   kHeaderButtonSpacing));
  gtk_widget_set_halign(self->header_title_box, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand(self->header_title_box, TRUE);

  track_widget_pointer(&self->onboarding_back_slot,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0));
  gtk_widget_set_size_request(self->onboarding_back_slot,
                              kHeaderOnboardingSideWidth, -1);
  gtk_widget_set_visible(self->onboarding_back_slot, FALSE);

  track_widget_pointer(&self->onboarding_back_button,
                       create_header_text_button("Back", "Back"));
  connect_header_bar_action(self, self->onboarding_back_button, "back");
  gtk_widget_set_visible(self->onboarding_back_button, FALSE);
  gtk_box_pack_start(GTK_BOX(self->onboarding_back_slot),
                     self->onboarding_back_button, FALSE, FALSE, 0);

  track_widget_pointer(&self->header_title_label,
                       gtk_label_new(""));
  gtk_style_context_add_class(gtk_widget_get_style_context(
                                  self->header_title_label),
                              "busymax-header-title");
  gtk_label_set_ellipsize(GTK_LABEL(self->header_title_label),
                          PANGO_ELLIPSIZE_END);
  gtk_label_set_max_width_chars(GTK_LABEL(self->header_title_label), 48);
  gtk_label_set_xalign(GTK_LABEL(self->header_title_label), 0.5);
  gtk_widget_set_halign(self->header_title_label, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand(self->header_title_label, TRUE);

  track_widget_pointer(&self->onboarding_continue_slot,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0));
  gtk_widget_set_size_request(self->onboarding_continue_slot,
                              kHeaderOnboardingSideWidth, -1);
  gtk_widget_set_visible(self->onboarding_continue_slot, FALSE);

  track_widget_pointer(&self->onboarding_continue_button,
                       create_header_text_button("Continue", "Continue"));
  gtk_style_context_add_class(
      gtk_widget_get_style_context(self->onboarding_continue_button),
      "busymax-header-primary-button");
  connect_header_bar_action(self, self->onboarding_continue_button,
                            "continueSetup");
  gtk_widget_set_visible(self->onboarding_continue_button, FALSE);
  gtk_box_pack_end(GTK_BOX(self->onboarding_continue_slot),
                   self->onboarding_continue_button, FALSE, FALSE, 0);

  gtk_box_pack_start(GTK_BOX(self->header_title_box),
                     self->onboarding_back_slot, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_title_box),
                     self->header_title_label, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(self->header_title_box),
                     self->onboarding_continue_slot, FALSE, FALSE, 0);
  gtk_header_bar_set_custom_title(header_bar, self->header_title_box);

  GtkWidget* end_box =
      gtk_box_new(GTK_ORIENTATION_HORIZONTAL, kHeaderButtonSpacing);

  track_widget_pointer(&self->header_view_box,
                       gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0));
  track_widget_pointer(&self->view_mode_menu, create_header_popup_window(self));
  GtkWidget* view_mode_menu_box =
      create_header_popover_box(self->view_mode_menu);

  track_widget_pointer(&self->view_mode_day_item,
                       create_header_view_mode_item(self, "day", "Day"));
  track_widget_pointer(&self->view_mode_week_item,
                       create_header_view_mode_item(self, "week", "Week"));
  track_widget_pointer(&self->view_mode_month_item,
                       create_header_view_mode_item(self, "month", "Month"));
  track_widget_pointer(&self->view_mode_year_item,
                       create_header_view_mode_item(self, "year", "Year"));
  track_widget_pointer(&self->view_mode_agenda_item,
                       create_header_view_mode_item(self, "agenda", "Agenda"));
  gtk_box_pack_start(GTK_BOX(view_mode_menu_box), self->view_mode_day_item,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(view_mode_menu_box), self->view_mode_week_item,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(view_mode_menu_box), self->view_mode_month_item,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(view_mode_menu_box), self->view_mode_year_item,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(view_mode_menu_box), self->view_mode_agenda_item,
                     FALSE, FALSE, 0);
  show_header_popover_content(view_mode_menu_box);

  track_widget_pointer(&self->view_mode_button, gtk_menu_button_new());
  gtk_button_set_relief(GTK_BUTTON(self->view_mode_button), GTK_RELIEF_NONE);
  gtk_style_context_add_class(gtk_widget_get_style_context(self->view_mode_button),
                              GTK_STYLE_CLASS_FLAT);
  gtk_style_context_add_class(gtk_widget_get_style_context(self->view_mode_button),
                              "busymax-header-view-mode-button");
  gtk_menu_button_set_use_popover(GTK_MENU_BUTTON(self->view_mode_button),
                                  TRUE);
  gtk_menu_button_set_popover(GTK_MENU_BUTTON(self->view_mode_button),
                              self->view_mode_menu);

  GtkWidget* view_mode_button_box =
      gtk_box_new(GTK_ORIENTATION_HORIZONTAL, kHeaderButtonSpacing);
  track_widget_pointer(&self->view_mode_label, gtk_label_new(""));
  gtk_label_set_ellipsize(GTK_LABEL(self->view_mode_label),
                          PANGO_ELLIPSIZE_END);
  GtkWidget* view_mode_arrow =
      gtk_image_new_from_icon_name("pan-down-symbolic", GTK_ICON_SIZE_MENU);
  gtk_box_pack_start(GTK_BOX(view_mode_button_box), self->view_mode_label,
                     TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(view_mode_button_box), view_mode_arrow,
                     FALSE, FALSE, 0);
  gtk_container_add(GTK_CONTAINER(self->view_mode_button),
                    view_mode_button_box);

  gtk_box_pack_start(GTK_BOX(self->header_view_box), self->view_mode_button,
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(end_box), self->header_view_box, FALSE, FALSE, 0);

  track_widget_pointer(&self->refresh_button,
                       create_header_icon_button("view-refresh-symbolic",
                                                 ""));
  connect_header_bar_action(self, self->refresh_button, "refresh");
  gtk_box_pack_start(GTK_BOX(end_box), self->refresh_button, FALSE, FALSE, 0);
  gtk_header_bar_pack_end(header_bar, end_box);

  set_header_view_mode(self, "week");
  set_header_back_visible(self, FALSE);
  set_header_schedule_controls_visible(self, TRUE);
  set_header_sidebar_visible(self, TRUE);
  gtk_box_pack_start(GTK_BOX(self->titlebar_box), GTK_WIDGET(header_bar), TRUE,
                     TRUE, 0);
  return self->titlebar_box;
}

static void header_bar_method_call_cb(FlMethodChannel* channel,
                                      FlMethodCall* method_call,
                                      gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (strcmp(method, "initialize") == 0) {
    respond_bool(method_call, has_header_bar(self));
  } else if (strcmp(method, "setTitleRange") == 0) {
    const gchar* value = fl_method_string_arg(args);
    if (self->header_title_label != nullptr &&
        GTK_IS_LABEL(self->header_title_label) && value != nullptr) {
      gtk_label_set_text(GTK_LABEL(self->header_title_label), value);
    }
    respond_success(method_call);
  } else if (strcmp(method, "setViewMode") == 0) {
    set_header_view_mode(self, fl_method_string_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setCanRefresh") == 0) {
    set_widget_sensitive(self->refresh_button, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setCanCreate") == 0) {
    respond_success(method_call);
  } else if (strcmp(method, "setLocalizedLabels") == 0) {
    set_header_localized_labels(self, args);
    respond_success(method_call);
  } else if (strcmp(method, "setSidebarWidth") == 0) {
    set_header_sidebar_width(self, fl_method_double_arg(args, 300));
    respond_success(method_call);
  } else if (strcmp(method, "setSearchActive") == 0) {
    set_toggle_button_active(self, self->search_button, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setSidebarVisible") == 0) {
    set_header_sidebar_visible(self, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setNavigationVisible") == 0) {
    set_header_navigation_visible(self, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setScheduleControlsVisible") == 0) {
    set_header_schedule_controls_visible(self, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setBackVisible") == 0) {
    set_header_back_visible(self, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setOnboardingControls") == 0) {
    set_header_onboarding_controls(self, args);
    respond_success(method_call);
  } else if (strcmp(method, "setModalBarrierVisible") == 0) {
    set_header_bar_modal_barrier_visible(self, fl_method_bool_arg(args));
    respond_success(method_call);
  } else if (strcmp(method, "setTheme") == 0) {
    set_header_bar_theme(self, args);
    respond_success(method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void register_header_bar_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->header_bar_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      kHeaderBarChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->header_bar_channel, header_bar_method_call_cb, self, nullptr);
}

static FlValue* parse_gtk_font_name(const gchar* font_name) {
  if (font_name == nullptr) {
    return fl_value_new_null();
  }

  PangoFontDescription* desc = pango_font_description_from_string(font_name);
  if (desc == nullptr) {
    return fl_value_new_null();
  }

  const gchar* family = pango_font_description_get_family(desc);
  const gint size = pango_font_description_get_size(desc);
  const double point_size =
      size > 0 ? static_cast<double>(size) / PANGO_SCALE : 0.0;

  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "family",
      fl_value_new_string(family != nullptr ? family : ""));
  fl_value_set_string_take(result, "size", fl_value_new_float(point_size));

  pango_font_description_free(desc);
  return result;
}

static FlValue* get_gtk_font_settings() {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) {
    return fl_value_new_null();
  }

  gchar* font_name = nullptr;
  g_object_get(settings, "gtk-font-name", &font_name, nullptr);
  FlValue* result = parse_gtk_font_name(font_name);
  g_free(font_name);
  return result;
}

static guint color_channel(double value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 1) {
    return 255;
  }
  return static_cast<guint>(value * 255.0 + 0.5);
}

static gboolean color_is_visible(const GdkRGBA* color) {
  return color != nullptr && color->alpha > 0.01;
}

static gchar* rgba_to_hex(const GdkRGBA* color) {
  const guint red = color_channel(color->red);
  const guint green = color_channel(color->green);
  const guint blue = color_channel(color->blue);
  const guint alpha = color_channel(color->alpha);
  if (alpha < 255) {
    return g_strdup_printf("#%02X%02X%02X%02X", alpha, red, green, blue);
  }
  return g_strdup_printf("#%02X%02X%02X", red, green, blue);
}

static void set_theme_color(FlValue* result,
                            const gchar* key,
                            const GdkRGBA* color) {
  if (!color_is_visible(color)) {
    return;
  }
  g_autofree gchar* hex = rgba_to_hex(color);
  fl_value_set_string_take(result, key, fl_value_new_string(hex));
}

static gboolean lookup_context_color(GtkStyleContext* context,
                                     const gchar* name,
                                     GdkRGBA* color) {
  if (context == nullptr || name == nullptr || color == nullptr) {
    return FALSE;
  }
  if (!gtk_style_context_lookup_color(context, name, color)) {
    return FALSE;
  }
  return color_is_visible(color);
}

static gboolean sample_widget_background(GtkWidget* widget,
                                         const gchar* style_class,
                                         GtkStateFlags state,
                                         GdkRGBA* color) {
  if (widget == nullptr || color == nullptr) {
    return FALSE;
  }
  GtkStyleContext* context = gtk_widget_get_style_context(widget);
  if (context == nullptr) {
    return FALSE;
  }
  if (style_class != nullptr) {
    gtk_style_context_add_class(context, style_class);
  }
  gtk_style_context_set_state(context, state);
  GValue value = G_VALUE_INIT;
  gtk_style_context_get_property(context, "background-color", state, &value);
  const GdkRGBA* background =
      static_cast<const GdkRGBA*>(g_value_get_boxed(&value));
  if (background != nullptr) {
    *color = *background;
  }
  g_value_unset(&value);
  return color_is_visible(color);
}

static gboolean sample_widget_color(GtkWidget* widget,
                                    const gchar* style_class,
                                    GtkStateFlags state,
                                    GdkRGBA* color) {
  if (widget == nullptr || color == nullptr) {
    return FALSE;
  }
  GtkStyleContext* context = gtk_widget_get_style_context(widget);
  if (context == nullptr) {
    return FALSE;
  }
  if (style_class != nullptr) {
    gtk_style_context_add_class(context, style_class);
  }
  gtk_style_context_set_state(context, state);
  gtk_style_context_get_color(context, state, color);
  return color_is_visible(color);
}

static const gchar* brightness_for_color(const GdkRGBA* color) {
  if (color == nullptr) {
    return "light";
  }
  const double luminance =
      (0.2126 * color->red) + (0.7152 * color->green) +
      (0.0722 * color->blue);
  return luminance < 0.5 ? "dark" : "light";
}

static FlValue* get_gtk_theme_colors() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWidget* view = gtk_text_view_new();
  GtkWidget* sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  GtkWidget* header = gtk_header_bar_new();
  GtkWidget* card = gtk_frame_new(nullptr);
  GtkWidget* dialog = gtk_dialog_new();
  GtkWidget* popover = gtk_popover_new(nullptr);
  GtkWidget* control = gtk_button_new();

  GdkRGBA window_color = {0, 0, 0, 0};
  GdkRGBA view_color = {0, 0, 0, 0};
  GdkRGBA sidebar_color = {0, 0, 0, 0};
  GdkRGBA header_color = {0, 0, 0, 0};
  GdkRGBA card_color = {0, 0, 0, 0};
  GdkRGBA dialog_color = {0, 0, 0, 0};
  GdkRGBA popover_color = {0, 0, 0, 0};
  GdkRGBA control_color = {0, 0, 0, 0};
  GdkRGBA control_hover_color = {0, 0, 0, 0};
  GdkRGBA control_active_color = {0, 0, 0, 0};
  GdkRGBA foreground_color = {0, 0, 0, 0};
  GdkRGBA muted_foreground_color = {0, 0, 0, 0};
  GdkRGBA border_color = {0, 0, 0, 0};
  GdkRGBA subtle_border_color = {0, 0, 0, 0};
  GdkRGBA sidebar_border_color = {0, 0, 0, 0};
  GdkRGBA shade_color = {0, 0, 0, 0};

  GtkStyleContext* window_context = gtk_widget_get_style_context(window);
  gtk_style_context_add_class(window_context, GTK_STYLE_CLASS_BACKGROUND);
  lookup_context_color(window_context, "theme_bg_color", &window_color) ||
      sample_widget_background(window, GTK_STYLE_CLASS_BACKGROUND,
                               GTK_STATE_FLAG_NORMAL, &window_color);
  lookup_context_color(window_context, "theme_base_color", &view_color) ||
      sample_widget_background(view, GTK_STYLE_CLASS_VIEW,
                               GTK_STATE_FLAG_NORMAL, &view_color);
  lookup_context_color(window_context, "theme_fg_color", &foreground_color) ||
      sample_widget_color(window, GTK_STYLE_CLASS_BACKGROUND,
                          GTK_STATE_FLAG_NORMAL, &foreground_color);
  lookup_context_color(window_context, "theme_unfocused_fg_color",
                       &muted_foreground_color);
  lookup_context_color(window_context, "borders", &border_color);

  sample_widget_background(sidebar, GTK_STYLE_CLASS_SIDEBAR,
                           GTK_STATE_FLAG_NORMAL, &sidebar_color);
  sample_widget_background(header, GTK_STYLE_CLASS_TITLEBAR,
                           GTK_STATE_FLAG_NORMAL, &header_color);
  sample_widget_background(card, "card", GTK_STATE_FLAG_NORMAL, &card_color);
  sample_widget_background(dialog, GTK_STYLE_CLASS_BACKGROUND,
                           GTK_STATE_FLAG_NORMAL, &dialog_color);
  sample_widget_background(popover, GTK_STYLE_CLASS_BACKGROUND,
                           GTK_STATE_FLAG_NORMAL, &popover_color);
  sample_widget_background(control, nullptr, GTK_STATE_FLAG_NORMAL,
                           &control_color);
  sample_widget_background(control, nullptr, GTK_STATE_FLAG_PRELIGHT,
                           &control_hover_color);
  sample_widget_background(control, nullptr, GTK_STATE_FLAG_ACTIVE,
                           &control_active_color);

  if (color_is_visible(&border_color)) {
    subtle_border_color = border_color;
    subtle_border_color.alpha *= 0.56;
    sidebar_border_color = border_color;
    sidebar_border_color.alpha *= 0.72;
    shade_color = border_color;
    shade_color.alpha *= 0.72;
  }

  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "brightness",
      fl_value_new_string(brightness_for_color(&window_color)));
  set_theme_color(result, "window", &window_color);
  set_theme_color(result, "view", &view_color);
  set_theme_color(result, "sidebar", &sidebar_color);
  set_theme_color(result, "secondarySidebar", &sidebar_color);
  set_theme_color(result, "headerbar", &header_color);
  set_theme_color(result, "headerbarFlat", &view_color);
  set_theme_color(result, "card", &card_color);
  set_theme_color(result, "dialog", &dialog_color);
  set_theme_color(result, "popover", &popover_color);
  set_theme_color(result, "control", &control_color);
  set_theme_color(result, "controlHover", &control_hover_color);
  set_theme_color(result, "controlActive", &control_active_color);
  set_theme_color(result, "activeToggle", &control_active_color);
  set_theme_color(result, "foreground", &foreground_color);
  set_theme_color(result, "mutedForeground", &muted_foreground_color);
  set_theme_color(result, "border", &border_color);
  set_theme_color(result, "subtleBorder", &subtle_border_color);
  set_theme_color(result, "sidebarBorder", &sidebar_border_color);
  set_theme_color(result, "shade", &shade_color);

  gtk_widget_destroy(control);
  gtk_widget_destroy(popover);
  gtk_widget_destroy(dialog);
  gtk_widget_destroy(card);
  gtk_widget_destroy(header);
  gtk_widget_destroy(sidebar);
  gtk_widget_destroy(view);
  gtk_widget_destroy(window);
  return result;
}

static void gtk_settings_method_call_cb(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "getGtkFont") == 0) {
    g_autoptr(FlValue) result = get_gtk_font_settings();
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "getGtkThemeColors") == 0) {
    g_autoptr(FlValue) result = get_gtk_theme_colors();
    fl_method_call_respond_success(method_call, result, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void disconnect_gtk_font_settings_signal(MyApplication* self) {
  if (self->gtk_font_settings_signal_id == 0) {
    return;
  }
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_signal_handler_disconnect(settings, self->gtk_font_settings_signal_id);
  }
  self->gtk_font_settings_signal_id = 0;
}

static void send_gtk_font_settings_event(MyApplication* self) {
  if (!self->gtk_font_settings_listening ||
      self->gtk_font_settings_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_font_settings();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_font_settings_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK font settings event: %s", message);
  }
}

static void gtk_font_name_notify_cb(GObject* object,
                                    GParamSpec* pspec,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  send_gtk_font_settings_event(self);
}

static FlMethodErrorResponse* gtk_font_settings_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_font_settings_listening = TRUE;

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_font_settings_signal_id == 0) {
    self->gtk_font_settings_signal_id =
        g_signal_connect(settings, "notify::gtk-font-name",
                         G_CALLBACK(gtk_font_name_notify_cb), self);
  }

  send_gtk_font_settings_event(self);
  return nullptr;
}

static FlMethodErrorResponse* gtk_font_settings_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_font_settings_listening = FALSE;
  disconnect_gtk_font_settings_signal(self);
  return nullptr;
}

static void disconnect_gtk_theme_colors_signals(MyApplication* self) {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_theme_name_signal_id != 0) {
    g_signal_handler_disconnect(settings, self->gtk_theme_name_signal_id);
  }
  if (settings != nullptr && self->gtk_theme_dark_signal_id != 0) {
    g_signal_handler_disconnect(settings, self->gtk_theme_dark_signal_id);
  }
  self->gtk_theme_name_signal_id = 0;
  self->gtk_theme_dark_signal_id = 0;
}

static void send_gtk_theme_colors_event(MyApplication* self) {
  if (!self->gtk_theme_colors_listening ||
      self->gtk_theme_colors_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_theme_colors();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_theme_colors_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK theme colors event: %s", message);
  }
}

static void gtk_theme_colors_notify_cb(GObject* object,
                                       GParamSpec* pspec,
                                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  send_gtk_theme_colors_event(self);
}

static FlMethodErrorResponse* gtk_theme_colors_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_theme_colors_listening = TRUE;

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_theme_name_signal_id == 0) {
    self->gtk_theme_name_signal_id =
        g_signal_connect(settings, "notify::gtk-theme-name",
                         G_CALLBACK(gtk_theme_colors_notify_cb), self);
  }
  if (settings != nullptr && self->gtk_theme_dark_signal_id == 0) {
    self->gtk_theme_dark_signal_id = g_signal_connect(
        settings, "notify::gtk-application-prefer-dark-theme",
        G_CALLBACK(gtk_theme_colors_notify_cb), self);
  }

  send_gtk_theme_colors_event(self);
  return nullptr;
}

static FlMethodErrorResponse* gtk_theme_colors_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_theme_colors_listening = FALSE;
  disconnect_gtk_theme_colors_signals(self);
  return nullptr;
}

static void register_gtk_settings_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  self->gtk_settings_channel = fl_method_channel_new(
      messenger, kGtkSettingsChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->gtk_settings_channel, gtk_settings_method_call_cb, self, nullptr);

  self->gtk_font_settings_event_channel = fl_event_channel_new(
      messenger, kGtkFontSettingsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_font_settings_event_channel, gtk_font_settings_listen_cb,
      gtk_font_settings_cancel_cb, self, nullptr);

  self->gtk_theme_colors_event_channel = fl_event_channel_new(
      messenger, kGtkThemeColorsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_theme_colors_event_channel, gtk_theme_colors_listen_cb,
      gtk_theme_colors_cancel_cb, self, nullptr);
}

struct CompactGtkSettingsBridge {
  FlMethodChannel* settings_channel;
  FlEventChannel* font_settings_event_channel;
  FlEventChannel* theme_colors_event_channel;
  gulong font_settings_signal_id;
  gulong theme_name_signal_id;
  gulong theme_dark_signal_id;
  gboolean font_settings_listening;
  gboolean theme_colors_listening;
};

static void compact_gtk_settings_bridge_disconnect_font(
    CompactGtkSettingsBridge* bridge) {
  if (bridge == nullptr || bridge->font_settings_signal_id == 0) {
    return;
  }
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_signal_handler_disconnect(settings, bridge->font_settings_signal_id);
  }
  bridge->font_settings_signal_id = 0;
}

static void compact_gtk_settings_bridge_disconnect_theme(
    CompactGtkSettingsBridge* bridge) {
  if (bridge == nullptr) {
    return;
  }
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && bridge->theme_name_signal_id != 0) {
    g_signal_handler_disconnect(settings, bridge->theme_name_signal_id);
  }
  if (settings != nullptr && bridge->theme_dark_signal_id != 0) {
    g_signal_handler_disconnect(settings, bridge->theme_dark_signal_id);
  }
  bridge->theme_name_signal_id = 0;
  bridge->theme_dark_signal_id = 0;
}

static void compact_gtk_settings_bridge_free(gpointer data) {
  CompactGtkSettingsBridge* bridge =
      static_cast<CompactGtkSettingsBridge*>(data);
  if (bridge == nullptr) {
    return;
  }
  compact_gtk_settings_bridge_disconnect_font(bridge);
  compact_gtk_settings_bridge_disconnect_theme(bridge);
  g_clear_object(&bridge->settings_channel);
  g_clear_object(&bridge->font_settings_event_channel);
  g_clear_object(&bridge->theme_colors_event_channel);
  g_free(bridge);
}

static void compact_gtk_settings_send_font_event(
    CompactGtkSettingsBridge* bridge) {
  if (bridge == nullptr || !bridge->font_settings_listening ||
      bridge->font_settings_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_font_settings();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(bridge->font_settings_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send compact GTK font settings event: %s", message);
  }
}

static void compact_gtk_settings_send_theme_event(
    CompactGtkSettingsBridge* bridge) {
  if (bridge == nullptr || !bridge->theme_colors_listening ||
      bridge->theme_colors_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_theme_colors();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(bridge->theme_colors_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send compact GTK theme colors event: %s", message);
  }
}

static void compact_gtk_font_notify_cb(GObject* object,
                                       GParamSpec* pspec,
                                       gpointer user_data) {
  compact_gtk_settings_send_font_event(
      static_cast<CompactGtkSettingsBridge*>(user_data));
}

static void compact_gtk_theme_notify_cb(GObject* object,
                                        GParamSpec* pspec,
                                        gpointer user_data) {
  compact_gtk_settings_send_theme_event(
      static_cast<CompactGtkSettingsBridge*>(user_data));
}

static FlMethodErrorResponse* compact_gtk_font_settings_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  CompactGtkSettingsBridge* bridge =
      static_cast<CompactGtkSettingsBridge*>(user_data);
  bridge->font_settings_listening = TRUE;

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && bridge->font_settings_signal_id == 0) {
    bridge->font_settings_signal_id =
        g_signal_connect(settings, "notify::gtk-font-name",
                         G_CALLBACK(compact_gtk_font_notify_cb), bridge);
  }

  compact_gtk_settings_send_font_event(bridge);
  return nullptr;
}

static FlMethodErrorResponse* compact_gtk_font_settings_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  CompactGtkSettingsBridge* bridge =
      static_cast<CompactGtkSettingsBridge*>(user_data);
  bridge->font_settings_listening = FALSE;
  compact_gtk_settings_bridge_disconnect_font(bridge);
  return nullptr;
}

static FlMethodErrorResponse* compact_gtk_theme_colors_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  CompactGtkSettingsBridge* bridge =
      static_cast<CompactGtkSettingsBridge*>(user_data);
  bridge->theme_colors_listening = TRUE;

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && bridge->theme_name_signal_id == 0) {
    bridge->theme_name_signal_id =
        g_signal_connect(settings, "notify::gtk-theme-name",
                         G_CALLBACK(compact_gtk_theme_notify_cb), bridge);
  }
  if (settings != nullptr && bridge->theme_dark_signal_id == 0) {
    bridge->theme_dark_signal_id = g_signal_connect(
        settings, "notify::gtk-application-prefer-dark-theme",
        G_CALLBACK(compact_gtk_theme_notify_cb), bridge);
  }

  compact_gtk_settings_send_theme_event(bridge);
  return nullptr;
}

static FlMethodErrorResponse* compact_gtk_theme_colors_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  CompactGtkSettingsBridge* bridge =
      static_cast<CompactGtkSettingsBridge*>(user_data);
  bridge->theme_colors_listening = FALSE;
  compact_gtk_settings_bridge_disconnect_theme(bridge);
  return nullptr;
}

static void register_compact_gtk_settings_channel(FlView* view,
                                                  GtkWindow* window) {
  CompactGtkSettingsBridge* bridge =
      g_new0(CompactGtkSettingsBridge, 1);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));

  bridge->settings_channel = fl_method_channel_new(
      messenger, kGtkSettingsChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      bridge->settings_channel, gtk_settings_method_call_cb, bridge, nullptr);

  bridge->font_settings_event_channel = fl_event_channel_new(
      messenger, kGtkFontSettingsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      bridge->font_settings_event_channel, compact_gtk_font_settings_listen_cb,
      compact_gtk_font_settings_cancel_cb, bridge, nullptr);

  bridge->theme_colors_event_channel = fl_event_channel_new(
      messenger, kGtkThemeColorsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      bridge->theme_colors_event_channel, compact_gtk_theme_colors_listen_cb,
      compact_gtk_theme_colors_cancel_cb, bridge, nullptr);

  g_object_set_data_full(G_OBJECT(window), "busymax-compact-gtk-settings",
                         bridge, compact_gtk_settings_bridge_free);
}

static gboolean window_delete_event_cb(GtkWidget* widget,
                                       GdkEvent* event,
                                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->hide_on_close) {
    gtk_widget_hide(widget);
    return TRUE;
  }
  return FALSE;
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (strcmp(method, "setHideOnClose") == 0) {
    self->hide_on_close =
        args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL
            ? fl_value_get_bool(args)
            : FALSE;
    respond_success(method_call);
  } else if (strcmp(method, "hideWindow") == 0) {
    if (self->main_window != nullptr) {
      gtk_widget_hide(GTK_WIDGET(self->main_window));
    }
    respond_success(method_call);
  } else if (strcmp(method, "showWindow") == 0) {
    if (self->main_window != nullptr) {
      gtk_widget_show(GTK_WIDGET(self->main_window));
      gtk_window_present(self->main_window);
    }
    respond_success(method_call);
  } else if (strcmp(method, "quitApp") == 0) {
    self->hide_on_close = FALSE;
    g_application_quit(G_APPLICATION(self));
    respond_success(method_call);
  } else if (strcmp(method, "isWindowVisible") == 0) {
    respond_bool(
        method_call,
        self->main_window != nullptr &&
            gtk_widget_get_visible(GTK_WIDGET(self->main_window)));
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void register_window_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kWindowChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, self, nullptr);
}

static gboolean clear_transparent_window_cb(GtkWidget* widget,
                                            cairo_t* cr,
                                            gpointer user_data) {
  cairo_save(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
  cairo_paint(cr);
  cairo_restore(cr);
  return FALSE;
}

static void rounded_window_realize_cb(GtkWidget* widget, gpointer user_data);

static gboolean rounded_window_configure_event_cb(GtkWidget* widget,
                                                  GdkEventConfigure* event,
                                                  gpointer user_data);

static gboolean configure_transparent_window_backing(GtkWindow* window) {
  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual == nullptr) {
    return FALSE;
  }

  gtk_widget_set_visual(GTK_WIDGET(window), visual);
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  g_signal_connect(window, "draw", G_CALLBACK(clear_transparent_window_cb),
                   nullptr);
  g_signal_connect_after(window, "realize", G_CALLBACK(rounded_window_realize_cb),
                         nullptr);
  g_signal_connect(window, "configure-event",
                   G_CALLBACK(rounded_window_configure_event_cb), nullptr);
  return TRUE;
}

static cairo_region_t* create_rounded_window_region(gint width,
                                                    gint height,
                                                    gint radius) {
  cairo_region_t* region = cairo_region_create();
  if (width <= 0 || height <= 0) {
    return region;
  }

  if (radius <= 0 || width < radius * 2 || height < radius * 2) {
    const cairo_rectangle_int_t rect = {0, 0, width, height};
    cairo_region_union_rectangle(region, &rect);
    return region;
  }

  const gdouble radius_squared = radius * radius;
  for (gint y = 0; y < height; y++) {
    gint inset = 0;
    if (y < radius) {
      const gdouble dy = radius - y - 1;
      inset = radius - static_cast<gint>(std::sqrt(radius_squared - dy * dy));
    } else if (y >= height - radius) {
      const gdouble dy = y - (height - radius);
      inset = radius - static_cast<gint>(std::sqrt(radius_squared - dy * dy));
    }

    const gint row_width = width - inset * 2;
    if (row_width <= 0) {
      continue;
    }

    const cairo_rectangle_int_t row = {inset, y, row_width, 1};
    cairo_region_union_rectangle(region, &row);
  }

  return region;
}

static void configure_rounded_window_shape(GtkWidget* widget) {
  if (widget == nullptr || !GTK_IS_WIDGET(widget) ||
      !gtk_widget_get_realized(widget)) {
    return;
  }

  GdkWindow* window = gtk_widget_get_window(widget);
  if (window == nullptr || !GDK_IS_WINDOW(window)) {
    return;
  }

  const GdkWindowState state = gdk_window_get_state(window);
  if ((state & GDK_WINDOW_STATE_MAXIMIZED) != 0 ||
      (state & GDK_WINDOW_STATE_FULLSCREEN) != 0) {
    gdk_window_shape_combine_region(window, nullptr, 0, 0);
    return;
  }

  const gint width = gtk_widget_get_allocated_width(widget);
  const gint height = gtk_widget_get_allocated_height(widget);
  if (width <= 0 || height <= 0) {
    return;
  }

  cairo_region_t* region =
      create_rounded_window_region(width, height, kHeaderWindowRadius);
  gdk_window_shape_combine_region(window, region, 0, 0);
  cairo_region_destroy(region);
}

static void rounded_window_realize_cb(GtkWidget* widget, gpointer user_data) {
  configure_rounded_window_shape(widget);
}

static gboolean rounded_window_configure_event_cb(GtkWidget* widget,
                                                  GdkEventConfigure* event,
                                                  gpointer user_data) {
  configure_rounded_window_shape(widget);
  return FALSE;
}

static void install_compact_agenda_window_css(GtkWindow* window) {
  static const gchar* css =
      "window#busymax-compact-agenda-window,"
      "window#busymax-compact-agenda-window:backdrop {"
      "background-color: transparent;"
      "background-image: none;"
      "}"
      "window#busymax-compact-agenda-window decoration,"
      "window#busymax-compact-agenda-window decoration:backdrop {"
      "background-color: transparent;"
      "background-image: none;"
      "border: none;"
      "}";

  g_autoptr(GError) error = nullptr;
  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(provider, css, -1, &error);
  if (error != nullptr) {
    g_warning("Failed to load compact Agenda CSS: %s", error->message);
    g_object_unref(provider);
    return;
  }

  gtk_style_context_add_provider_for_screen(
      gtk_window_get_screen(window), GTK_STYLE_PROVIDER(provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(provider);
}

static gboolean compact_agenda_number_arg(FlValue* args,
                                           const gchar* key,
                                           gdouble* value) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* arg = fl_value_lookup_string(args, key);
  if (arg == nullptr) {
    return FALSE;
  }

  switch (fl_value_get_type(arg)) {
    case FL_VALUE_TYPE_FLOAT:
      *value = fl_value_get_float(arg);
      return std::isfinite(*value);
    case FL_VALUE_TYPE_INT:
      *value = static_cast<gdouble>(fl_value_get_int(arg));
      return std::isfinite(*value);
    default:
      return FALSE;
  }
}

static gint compact_agenda_dimension_arg(FlValue* args,
                                          const gchar* key,
                                          gint fallback,
                                          gint minimum,
                                          gint maximum) {
  gdouble value = fallback;
  if (!compact_agenda_number_arg(args, key, &value)) {
    return fallback;
  }
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return static_cast<gint>(value);
}

static gboolean compact_agenda_position_arg(FlValue* args,
                                             const gchar* key,
                                             gint* value) {
  gdouble parsed = 0;
  if (!compact_agenda_number_arg(args, key, &parsed)) {
    return FALSE;
  }
  *value = static_cast<gint>(parsed);
  return TRUE;
}

static void apply_compact_agenda_geometry(GtkWindow* window, FlValue* args) {
  const gint width = compact_agenda_dimension_arg(
      args, "width", kCompactAgendaWindowWidth, kCompactAgendaWindowMinWidth,
      kCompactAgendaWindowMaxWidth);
  const gint height = compact_agenda_dimension_arg(
      args, "height", kCompactAgendaWindowHeight, kCompactAgendaWindowMinHeight,
      kCompactAgendaWindowMaxHeight);

  gtk_window_set_position(window, GTK_WIN_POS_NONE);
  gtk_window_set_default_size(window, width, height);
  gtk_window_resize(window, width, height);
  gtk_widget_set_size_request(GTK_WIDGET(window), width, height);

  GtkWidget* child = gtk_bin_get_child(GTK_BIN(window));
  if (child != nullptr) {
    gtk_widget_set_size_request(child, width, height);
  }

  gint x = 0;
  gint y = 0;
  if (compact_agenda_position_arg(args, "x", &x) &&
      compact_agenda_position_arg(args, "y", &y)) {
    gtk_window_move(window, x, y);
  }
}

static void compact_agenda_window_method_call_cb(FlMethodChannel* channel,
                                                  FlMethodCall* method_call,
                                                  gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "setPlacement") == 0) {
    apply_compact_agenda_geometry(window, args);
    respond_bool(method_call, TRUE);
  } else if (strcmp(method, "show") == 0) {
    apply_compact_agenda_geometry(window, args);
    gtk_widget_show(GTK_WIDGET(window));
    gtk_window_present(window);
    apply_compact_agenda_geometry(window, args);
    respond_bool(method_call, TRUE);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void register_compact_agenda_window_channel(FlView* view,
                                                   GtkWindow* window) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      kCompactAgendaWindowChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, compact_agenda_window_method_call_cb, g_object_ref(window),
      g_object_unref);
  g_object_set_data_full(G_OBJECT(window), "busymax-compact-agenda-channel",
                         channel, g_object_unref);
}

static void configure_compact_agenda_subwindow(FlPluginRegistry* registry) {
  // BusyMax creates desktop_multi_window subwindows for the compact tray
  // Agenda. Configure the GTK shell before Dart/window_manager can show the
  // plugin's default 1280x720 secondary window.
  if (!FL_IS_VIEW(registry)) {
    return;
  }

  FlView* view = FL_VIEW(registry);
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (!GTK_IS_WINDOW(toplevel)) {
    return;
  }

  GtkWindow* window = GTK_WINDOW(toplevel);
  GdkRGBA transparent = {0, 0, 0, 0};
  fl_view_set_background_color(view, &transparent);

  gtk_widget_set_name(GTK_WIDGET(window), "busymax-compact-agenda-window");
  install_compact_agenda_window_css(window);
  GtkWidget* titlebar = gtk_window_get_titlebar(window);
  if (titlebar != nullptr) {
    gtk_widget_hide(titlebar);
  }
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_type_hint(window, GDK_WINDOW_TYPE_HINT_UTILITY);
  gtk_window_set_skip_taskbar_hint(window, TRUE);
  gtk_window_set_skip_pager_hint(window, TRUE);
  gtk_window_set_keep_above(window, TRUE);
  gtk_window_set_gravity(window, GDK_GRAVITY_NORTH_EAST);
  gtk_window_set_position(window, GTK_WIN_POS_NONE);
  gtk_window_set_title(window, "BusyMax Agenda");
  gtk_window_set_resizable(window, FALSE);
  gtk_window_set_default_size(window, kCompactAgendaWindowWidth,
                              kCompactAgendaWindowHeight);
  gtk_window_resize(window, kCompactAgendaWindowWidth,
                    kCompactAgendaWindowHeight);
  gtk_widget_set_size_request(GTK_WIDGET(window), kCompactAgendaWindowWidth,
                              kCompactAgendaWindowHeight);
  gtk_widget_set_size_request(GTK_WIDGET(view), kCompactAgendaWindowWidth,
                              kCompactAgendaWindowHeight);

  GdkGeometry geometry = {};
  geometry.min_width = kCompactAgendaWindowMinWidth;
  geometry.min_height = kCompactAgendaWindowMinHeight;
  geometry.max_width = kCompactAgendaWindowMaxWidth;
  geometry.max_height = kCompactAgendaWindowMaxHeight;
  gtk_window_set_geometry_hints(
      window, GTK_WIDGET(window), &geometry,
      static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));

  register_compact_agenda_window_channel(view, window);
  register_compact_gtk_settings_channel(view, window);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->main_window = window;
  gtk_widget_set_name(GTK_WIDGET(window), "busymax-window");
  self->main_window_transparent_backing =
      configure_transparent_window_backing(window);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkWidget* titlebar = create_busymax_header_bar(self);
    gtk_widget_show_all(titlebar);
    gtk_window_set_titlebar(window, titlebar);
  } else {
    gtk_window_set_title(window, kApplicationDisplayName);
  }

  g_autoptr(GdkPixbuf) application_icon = load_application_icon();
  if (application_icon != nullptr) {
    gtk_window_set_default_icon(application_icon);
    gtk_window_set_icon(window, application_icon);
  }
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  gtk_window_set_wmclass(
      window, APPLICATION_ID, APPLICATION_ID);
  G_GNUC_END_IGNORE_DEPRECATIONS
  gtk_window_set_icon_name(window, APPLICATION_ID);
  gtk_window_set_default_size(window, 1280, 720);
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_event_cb),
                   self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  track_widget_pointer(&self->flutter_view, GTK_WIDGET(view));
  set_main_flutter_view_background(self);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  desktop_multi_window_plugin_set_window_created_callback(
      [](FlPluginRegistry* registry) {
        configure_compact_agenda_subwindow(registry);
        fl_register_plugins(registry);
      });
  register_native_date_time_picker(self, view, window);
  register_window_channel(self, view);
  register_header_bar_channel(self, view);
  register_gtk_settings_channel(self, view);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->header_bar_css_provider != nullptr) {
    gtk_style_context_remove_provider_for_screen(
        gdk_screen_get_default(), GTK_STYLE_PROVIDER(self->header_bar_css_provider));
    g_clear_object(&self->header_bar_css_provider);
  }
  g_clear_object(&self->native_date_time_picker_channel);
  g_clear_object(&self->window_channel);
  g_clear_object(&self->header_bar_channel);
  g_clear_object(&self->gtk_settings_channel);
  disconnect_gtk_font_settings_signal(self);
  g_clear_object(&self->gtk_font_settings_event_channel);
  disconnect_gtk_theme_colors_signals(self);
  g_clear_object(&self->gtk_theme_colors_event_channel);
  self->main_window = nullptr;
  clear_widget_pointer(&self->flutter_view);
  clear_widget_pointer(&self->titlebar_box);
  clear_header_bar_pointer(self);
  clear_widget_pointer(&self->header_start_box);
  clear_widget_pointer(&self->header_title_balance_spacer);
  clear_widget_pointer(&self->header_title_box);
  clear_widget_pointer(&self->onboarding_back_slot);
  clear_widget_pointer(&self->onboarding_back_button);
  clear_widget_pointer(&self->onboarding_continue_slot);
  clear_widget_pointer(&self->onboarding_continue_button);
  clear_widget_pointer(&self->header_sidebar_brand_box);
  clear_widget_pointer(&self->header_brand_label);
  clear_widget_pointer(&self->settings_menu_button);
  clear_widget_pointer(&self->settings_menu);
  clear_widget_pointer(&self->settings_item);
  clear_widget_pointer(&self->about_item);
  clear_widget_pointer(&self->header_view_box);
  clear_widget_pointer(&self->header_title_label);
  clear_widget_pointer(&self->back_button);
  clear_widget_pointer(&self->sidebar_collapsed_toggle_button);
  clear_widget_pointer(&self->today_button);
  clear_widget_pointer(&self->previous_button);
  clear_widget_pointer(&self->next_button);
  clear_widget_pointer(&self->view_mode_button);
  clear_widget_pointer(&self->view_mode_label);
  clear_widget_pointer(&self->view_mode_menu);
  clear_widget_pointer(&self->view_mode_day_item);
  clear_widget_pointer(&self->view_mode_week_item);
  clear_widget_pointer(&self->view_mode_month_item);
  clear_widget_pointer(&self->view_mode_year_item);
  clear_widget_pointer(&self->view_mode_agenda_item);
  clear_widget_pointer(&self->search_button);
  clear_widget_pointer(&self->refresh_button);
  g_clear_pointer(&self->header_bar_window_background_color, g_free);
  g_clear_pointer(&self->header_bar_background_color, g_free);
  g_clear_pointer(&self->header_bar_sidebar_background_color, g_free);
  g_clear_pointer(&self->header_bar_foreground_color, g_free);
  g_clear_pointer(&self->header_bar_muted_foreground_color, g_free);
  g_clear_pointer(&self->header_bar_disabled_foreground_color, g_free);
  g_clear_pointer(&self->header_bar_control_color, g_free);
  g_clear_pointer(&self->header_bar_control_hover_color, g_free);
  g_clear_pointer(&self->header_bar_control_active_color, g_free);
  g_clear_pointer(&self->header_bar_accent_color, g_free);
  g_clear_pointer(&self->header_bar_accent_foreground_color, g_free);
  g_clear_pointer(&self->header_bar_popover_background_color, g_free);
  g_clear_pointer(&self->header_bar_border_color, g_free);
  g_clear_pointer(&self->header_bar_shade_color, g_free);
  g_clear_pointer(&self->header_bar_modal_barrier_color, g_free);
  g_clear_pointer(&self->header_view_mode, g_free);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->native_date_time_picker_channel = nullptr;
  self->window_channel = nullptr;
  self->header_bar_channel = nullptr;
  self->gtk_settings_channel = nullptr;
  self->gtk_font_settings_event_channel = nullptr;
  self->gtk_theme_colors_event_channel = nullptr;
  self->gtk_font_settings_signal_id = 0;
  self->gtk_theme_name_signal_id = 0;
  self->gtk_theme_dark_signal_id = 0;
  self->gtk_font_settings_listening = FALSE;
  self->gtk_theme_colors_listening = FALSE;
  self->hide_on_close = FALSE;
  self->suppress_header_bar_actions = FALSE;
  self->header_schedule_controls_visible = TRUE;
  self->header_back_visible = FALSE;
  self->header_onboarding_controls_visible = FALSE;
  self->main_window_transparent_backing = FALSE;
  self->header_bar_css_provider = nullptr;
  self->header_bar_window_background_color =
      g_strdup(kDefaultHeaderBarBackgroundColor);
  self->header_bar_background_color =
      g_strdup(kDefaultHeaderBarBackgroundColor);
  self->header_bar_sidebar_background_color =
      g_strdup(kDefaultHeaderBarSidebarBackgroundColor);
  self->header_bar_foreground_color = nullptr;
  self->header_bar_muted_foreground_color = nullptr;
  self->header_bar_disabled_foreground_color = nullptr;
  self->header_bar_control_color = nullptr;
  self->header_bar_control_hover_color = nullptr;
  self->header_bar_control_active_color = nullptr;
  self->header_bar_accent_color = nullptr;
  self->header_bar_accent_foreground_color = nullptr;
  self->header_bar_popover_background_color = nullptr;
  self->header_bar_border_color = nullptr;
  self->header_bar_shade_color = nullptr;
  self->header_bar_modal_barrier_color = nullptr;
  self->header_bar_sidebar_width = 300;
  self->header_bar_sidebar_visible = TRUE;
  self->header_bar_modal_barrier_visible = FALSE;
  self->main_window = nullptr;
  self->flutter_view = nullptr;
  self->titlebar_box = nullptr;
  self->header_bar = nullptr;
  self->header_start_box = nullptr;
  self->header_title_balance_spacer = nullptr;
  self->header_title_box = nullptr;
  self->onboarding_back_slot = nullptr;
  self->onboarding_back_button = nullptr;
  self->onboarding_continue_slot = nullptr;
  self->onboarding_continue_button = nullptr;
  self->header_sidebar_brand_box = nullptr;
  self->header_brand_label = nullptr;
  self->settings_menu_button = nullptr;
  self->settings_menu = nullptr;
  self->settings_item = nullptr;
  self->about_item = nullptr;
  self->header_view_box = nullptr;
  self->header_title_label = nullptr;
  self->back_button = nullptr;
  self->sidebar_collapsed_toggle_button = nullptr;
  self->today_button = nullptr;
  self->previous_button = nullptr;
  self->next_button = nullptr;
  self->view_mode_button = nullptr;
  self->view_mode_label = nullptr;
  self->view_mode_menu = nullptr;
  self->view_mode_day_item = nullptr;
  self->view_mode_week_item = nullptr;
  self->view_mode_month_item = nullptr;
  self->view_mode_year_item = nullptr;
  self->view_mode_agenda_item = nullptr;
  self->search_button = nullptr;
  self->refresh_button = nullptr;
  self->header_view_mode = nullptr;
  self->header_navigation_visible = TRUE;
}

MyApplication* my_application_new() {
  g_set_application_name(kApplicationDisplayName);
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
