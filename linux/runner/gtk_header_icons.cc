#include "gtk_header_icons.h"

#include <algorithm>
#include <utility>

namespace {

GtkIconLookupFlags LookupFlags(BusyMaxGtkIconDirection direction) {
  const GtkIconLookupFlags directional =
      direction == BusyMaxGtkIconDirection::kRtl ? GTK_ICON_LOOKUP_DIR_RTL
                                                 : GTK_ICON_LOOKUP_DIR_LTR;
  return static_cast<GtkIconLookupFlags>(directional |
                                         GTK_ICON_LOOKUP_FORCE_SYMBOLIC);
}

std::string FirstAvailableName(GtkIconTheme* theme,
                               const std::vector<std::string>& names) {
  const auto available = std::find_if(
      names.begin(), names.end(),
      [theme](const std::string& name) {
        return gtk_icon_theme_has_icon(theme, name.c_str());
      });
  return available == names.end() ? std::string() : *available;
}

}  // namespace

BusyMaxGtkHeaderIcons::BusyMaxGtkHeaderIcons(GtkWidget* flutter_view,
                                             GtkIconTheme* icon_theme)
    : flutter_view_(flutter_view), injected_theme_(icon_theme) {
  if (flutter_view_ != nullptr) g_object_ref(flutter_view_);
  if (injected_theme_ != nullptr) g_object_ref(injected_theme_);
}

BusyMaxGtkHeaderIcons::~BusyMaxGtkHeaderIcons() {
  Stop();
  g_clear_object(&injected_theme_);
  g_clear_object(&flutter_view_);
}

std::optional<BusyMaxGtkHeaderIconAsset> BusyMaxGtkHeaderIcons::Load(
    const std::vector<std::string>& candidate_names,
    BusyMaxGtkIconDirection direction,
    int scale_override,
    bool allow_missing) const {
  if (candidate_names.empty()) return std::nullopt;
  GtkIconTheme* theme = icon_theme_ != nullptr ? icon_theme_ : ResolveTheme();
  if (theme == nullptr) {
    if (!allow_missing) {
      g_warning("GTK could not resolve BusyMax header icon '%s'",
                candidate_names.front().c_str());
    }
    return std::nullopt;
  }

  const int requested_scale =
      scale_override > 0 ? scale_override : scale();
  GtkIconInfo* info = nullptr;
  if (candidate_names.size() == 1) {
    info = gtk_icon_theme_lookup_icon_for_scale(
        theme, candidate_names.front().c_str(),
        kBusyMaxGtkHeaderIconLogicalSize, requested_scale,
        LookupFlags(direction));
  } else {
    std::vector<const gchar*> names;
    names.reserve(candidate_names.size() + 1);
    for (const std::string& name : candidate_names) {
      names.push_back(name.c_str());
    }
    names.push_back(nullptr);
    info = gtk_icon_theme_choose_icon_for_scale(
        theme, names.data(), kBusyMaxGtkHeaderIconLogicalSize,
        requested_scale, LookupFlags(direction));
  }
  if (info == nullptr) {
    if (!allow_missing) {
      g_warning("GTK could not resolve BusyMax header icon '%s'",
                candidate_names.front().c_str());
    }
    return std::nullopt;
  }
  g_autoptr(GtkIconInfo) owned_info = info;

  const GdkRGBA white = {1.0, 1.0, 1.0, 1.0};
  gboolean was_symbolic = FALSE;
  g_autoptr(GError) load_error = nullptr;
  g_autoptr(GdkPixbuf) pixbuf = gtk_icon_info_load_symbolic(
      owned_info, &white, &white, &white, &white, &was_symbolic,
      &load_error);
  if (pixbuf == nullptr) {
    if (load_error != nullptr) {
      g_warning("Failed to load GTK header icon: %s", load_error->message);
    }
    return std::nullopt;
  }

  gchar* encoded = nullptr;
  gsize encoded_length = 0;
  g_autoptr(GError) encode_error = nullptr;
  if (!gdk_pixbuf_save_to_buffer(pixbuf, &encoded, &encoded_length, "png",
                                 &encode_error, nullptr)) {
    if (encode_error != nullptr) {
      g_warning("Failed to encode GTK header icon: %s",
                encode_error->message);
    }
    return std::nullopt;
  }
  std::vector<std::uint8_t> png_bytes(
      reinterpret_cast<std::uint8_t*>(encoded),
      reinterpret_cast<std::uint8_t*>(encoded) + encoded_length);
  g_free(encoded);

  std::string resolved_name = FirstAvailableName(theme, candidate_names);
  if (resolved_name.empty()) resolved_name = candidate_names.front();
  return BusyMaxGtkHeaderIconAsset{
      std::move(png_bytes),
      std::move(resolved_name),
      requested_scale,
      gdk_pixbuf_get_width(pixbuf),
      gdk_pixbuf_get_height(pixbuf),
  };
}

bool BusyMaxGtkHeaderIcons::Start(InvalidatedCallback callback) {
  callback_ = std::move(callback);
  if (flutter_view_ != nullptr && scale_changed_signal_id_ == 0) {
    scale_changed_signal_id_ = g_signal_connect(
        flutter_view_, "notify::scale-factor", G_CALLBACK(OnScaleChanged),
        this);
  }
  if (flutter_view_ != nullptr && screen_changed_signal_id_ == 0) {
    screen_changed_signal_id_ = g_signal_connect(
        flutter_view_, "screen-changed", G_CALLBACK(OnScreenChanged), this);
  }
  RebindTheme();
  return icon_theme_ != nullptr;
}

void BusyMaxGtkHeaderIcons::Stop() {
  if (icon_theme_ != nullptr && theme_changed_signal_id_ != 0 &&
      g_signal_handler_is_connected(icon_theme_, theme_changed_signal_id_)) {
    g_signal_handler_disconnect(icon_theme_, theme_changed_signal_id_);
  }
  theme_changed_signal_id_ = 0;
  g_clear_object(&icon_theme_);

  if (flutter_view_ != nullptr && scale_changed_signal_id_ != 0 &&
      g_signal_handler_is_connected(flutter_view_,
                                    scale_changed_signal_id_)) {
    g_signal_handler_disconnect(flutter_view_, scale_changed_signal_id_);
  }
  if (flutter_view_ != nullptr && screen_changed_signal_id_ != 0 &&
      g_signal_handler_is_connected(flutter_view_,
                                    screen_changed_signal_id_)) {
    g_signal_handler_disconnect(flutter_view_, screen_changed_signal_id_);
  }
  scale_changed_signal_id_ = 0;
  screen_changed_signal_id_ = 0;
  callback_ = nullptr;
}

int BusyMaxGtkHeaderIcons::scale() const {
  return flutter_view_ != nullptr
             ? std::max(1, gtk_widget_get_scale_factor(flutter_view_))
             : 1;
}

gulong BusyMaxGtkHeaderIcons::theme_changed_signal_id() const {
  return theme_changed_signal_id_;
}

gulong BusyMaxGtkHeaderIcons::scale_changed_signal_id() const {
  return scale_changed_signal_id_;
}

gulong BusyMaxGtkHeaderIcons::screen_changed_signal_id() const {
  return screen_changed_signal_id_;
}

void BusyMaxGtkHeaderIcons::OnThemeChanged(GtkIconTheme*, gpointer user_data) {
  static_cast<BusyMaxGtkHeaderIcons*>(user_data)->Invalidate();
}

void BusyMaxGtkHeaderIcons::OnScaleChanged(GObject*, GParamSpec*,
                                           gpointer user_data) {
  static_cast<BusyMaxGtkHeaderIcons*>(user_data)->Invalidate();
}

void BusyMaxGtkHeaderIcons::OnScreenChanged(GtkWidget*, GdkScreen*,
                                            gpointer user_data) {
  auto* icons = static_cast<BusyMaxGtkHeaderIcons*>(user_data);
  icons->RebindTheme();
  icons->Invalidate();
}

GtkIconTheme* BusyMaxGtkHeaderIcons::ResolveTheme() const {
  if (injected_theme_ != nullptr) return injected_theme_;
  if (flutter_view_ != nullptr) {
    GdkScreen* screen = gtk_widget_get_screen(flutter_view_);
    if (screen != nullptr) return gtk_icon_theme_get_for_screen(screen);
  }
  return gtk_icon_theme_get_default();
}

void BusyMaxGtkHeaderIcons::RebindTheme() {
  GtkIconTheme* next_theme = ResolveTheme();
  if (next_theme == icon_theme_) return;
  if (icon_theme_ != nullptr && theme_changed_signal_id_ != 0 &&
      g_signal_handler_is_connected(icon_theme_, theme_changed_signal_id_)) {
    g_signal_handler_disconnect(icon_theme_, theme_changed_signal_id_);
  }
  theme_changed_signal_id_ = 0;
  g_clear_object(&icon_theme_);
  if (next_theme == nullptr) return;
  icon_theme_ = GTK_ICON_THEME(g_object_ref(next_theme));
  theme_changed_signal_id_ = g_signal_connect(
      icon_theme_, "changed", G_CALLBACK(OnThemeChanged), this);
}

void BusyMaxGtkHeaderIcons::Invalidate() {
  if (callback_) callback_();
}
