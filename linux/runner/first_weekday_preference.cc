#include "first_weekday_preference.h"

#include "first_weekday.h"

#include <string>
#include <utility>

namespace {

constexpr char kPortalName[] = "org.freedesktop.portal.Desktop";
constexpr char kPortalPath[] = "/org/freedesktop/portal/desktop";
constexpr char kPortalInterface[] = "org.freedesktop.portal.Settings";
constexpr char kPortalReadOne[] = "ReadOne";
constexpr char kPortalChanged[] = "SettingChanged";
constexpr char kCalendarNamespace[] = "org.gnome.desktop.calendar";
constexpr char kWeekStartKey[] = "week-start-day";

enum class OverrideKind { kExplicit, kDefault, kInvalid };

struct OverrideValue {
  OverrideKind kind = OverrideKind::kInvalid;
  int weekday = 0;
};

OverrideValue ParseOverride(const gchar* value) {
  if (value == nullptr) return {};
  if (g_str_equal(value, "default")) {
    return {OverrideKind::kDefault, 0};
  }
  constexpr const char* kWeekdays[] = {
      "monday", "tuesday", "wednesday", "thursday",
      "friday", "saturday", "sunday",
  };
  for (int index = 0; index < 7; ++index) {
    if (g_str_equal(value, kWeekdays[index])) {
      return {OverrideKind::kExplicit, index + 1};
    }
  }
  return {};
}

OverrideValue ParseStringVariant(GVariant* value) {
  if (value == nullptr || !g_variant_is_of_type(value, G_VARIANT_TYPE_STRING)) {
    return {};
  }
  return ParseOverride(g_variant_get_string(value, nullptr));
}

OverrideValue ParsePortalReply(GVariant* reply) {
  if (reply == nullptr || !g_variant_is_of_type(reply, G_VARIANT_TYPE_TUPLE) ||
      g_variant_n_children(reply) != 1) {
    return {};
  }
  g_autoptr(GVariant) wrapped = g_variant_get_child_value(reply, 0);
  if (!g_variant_is_of_type(wrapped, G_VARIANT_TYPE_VARIANT)) return {};
  g_autoptr(GVariant) value = g_variant_get_variant(wrapped);
  return ParseStringVariant(value);
}

}  // namespace

struct BusyMaxLinuxFirstWeekdayPreference::State
    : public std::enable_shared_from_this<State> {
  struct Operation {
    explicit Operation(ReadCallback value)
        : callback(std::move(value)), cancellable(g_cancellable_new()) {}
    ~Operation() { g_clear_object(&cancellable); }

    ReadCallback callback;
    GCancellable* cancellable;
    guint timeout_id = 0;
    bool completed = false;
  };

  struct AsyncContext {
    std::shared_ptr<State> state;
    std::shared_ptr<Operation> operation;
  };

  explicit State(Configuration configuration)
      : direct_schema(configuration.direct_schema),
        direct_key(configuration.direct_key),
        locale_reader(configuration.locale_reader
                          ? std::move(configuration.locale_reader)
                          : LocaleReader(BusyMaxReadFirstWeekday)),
        portal_timeout_milliseconds(
            configuration.portal_timeout_milliseconds) {
    if (configuration.portal_connection != nullptr) {
      portal_connection = G_DBUS_CONNECTION(
          g_object_ref(configuration.portal_connection));
    }
    if (configuration.schema_source != nullptr) {
      schema_source =
          g_settings_schema_source_ref(configuration.schema_source);
    }
  }

  ~State() {
    DisconnectWatchers();
    g_clear_object(&direct_settings);
    g_clear_object(&portal_connection);
    if (schema_source != nullptr) {
      g_settings_schema_source_unref(schema_source);
      schema_source = nullptr;
    }
  }

  static void DeleteAsyncContext(gpointer data) {
    delete static_cast<AsyncContext*>(data);
  }

  void Dispose() {
    if (disposed) return;
    disposed = true;
    change_callback = nullptr;
    DisconnectWatchers();
    CancelActive(false);
  }

  void Read(ReadCallback callback) {
    if (disposed) return;
    CancelActive(true);
    auto operation = std::make_shared<Operation>(std::move(callback));
    active = operation;
    auto* timeout_context = new AsyncContext{shared_from_this(), operation};
    operation->timeout_id = g_timeout_add_full(
        G_PRIORITY_DEFAULT, portal_timeout_milliseconds, PortalTimeout,
        timeout_context, DeleteAsyncContext);
    if (portal_connection != nullptr) {
      SubscribePortal();
      CallPortal(operation);
      return;
    }

    auto* context = new AsyncContext{shared_from_this(), operation};
    g_bus_get(G_BUS_TYPE_SESSION, operation->cancellable, BusReady, context);
  }

  void CancelActive(bool complete) {
    const auto operation = active;
    if (!operation || operation->completed) return;
    active.reset();
    operation->completed = true;
    if (operation->timeout_id != 0) {
      g_source_remove(operation->timeout_id);
      operation->timeout_id = 0;
    }
    g_cancellable_cancel(operation->cancellable);
    auto callback = std::move(operation->callback);
    if (complete && !disposed && callback) callback(std::nullopt);
  }

  void Complete(const std::shared_ptr<Operation>& operation,
                std::optional<int> value) {
    if (operation->completed) return;
    operation->completed = true;
    if (operation->timeout_id != 0) {
      g_source_remove(operation->timeout_id);
      operation->timeout_id = 0;
    }
    if (active == operation) active.reset();
    auto callback = std::move(operation->callback);
    if (!disposed && callback) callback(value);
  }

  std::optional<int> ReadLocale() const {
    return locale_reader ? locale_reader() : std::nullopt;
  }

  void CompleteOverride(const std::shared_ptr<Operation>& operation,
                        OverrideValue override) {
    if (override.kind == OverrideKind::kExplicit) {
      Complete(operation, override.weekday);
    } else {
      // Both GNOME's recognized `default` and malformed successful portal
      // replies fall back to the locale. A stale sandbox-local value must not
      // supersede a successful host result.
      Complete(operation, ReadLocale());
    }
  }

  void ReadDirect(const std::shared_ptr<Operation>& operation) {
    if (disposed || operation->completed) return;
    if (direct_settings == nullptr) {
      GSettingsSchemaSource* source = schema_source != nullptr
                                          ? schema_source
                                          : g_settings_schema_source_get_default();
      if (source == nullptr) {
        Complete(operation, ReadLocale());
        return;
      }
      GSettingsSchema* schema = g_settings_schema_source_lookup(
          source, direct_schema.c_str(), TRUE);
      if (schema == nullptr) {
        Complete(operation, ReadLocale());
        return;
      }
      if (!g_settings_schema_has_key(schema, direct_key.c_str())) {
        g_settings_schema_unref(schema);
        Complete(operation, ReadLocale());
        return;
      }
      direct_settings = g_settings_new_full(schema, nullptr, nullptr);
      g_settings_schema_unref(schema);
    }
    ConnectDirect();
    // GLib only guarantees later changed signals for keys read while a
    // handler is connected, so the connection above intentionally precedes
    // this initial value read.
    g_autoptr(GVariant) value =
        g_settings_get_value(direct_settings, direct_key.c_str());
    CompleteOverride(operation, ParseStringVariant(value));
  }

  void CallPortal(const std::shared_ptr<Operation>& operation) {
    if (disposed || operation->completed || portal_connection == nullptr) {
      return;
    }
    auto* context = new AsyncContext{shared_from_this(), operation};
    g_dbus_connection_call(
        portal_connection, kPortalName, kPortalPath, kPortalInterface,
        kPortalReadOne, g_variant_new("(ss)", kCalendarNamespace,
                                     kWeekStartKey),
        G_VARIANT_TYPE("(v)"), G_DBUS_CALL_FLAGS_NONE,
        static_cast<gint>(portal_timeout_milliseconds),
        operation->cancellable, PortalRead, context);
  }

  static void BusReady(GObject*, GAsyncResult* result,
                       gpointer user_data) {
    std::unique_ptr<AsyncContext> context(
        static_cast<AsyncContext*>(user_data));
    auto& state = context->state;
    auto& operation = context->operation;
    g_autoptr(GError) error = nullptr;
    GDBusConnection* connection = g_bus_get_finish(result, &error);
    if (operation->completed || state->disposed) {
      if (connection != nullptr) g_object_unref(connection);
      return;
    }
    if (connection == nullptr) {
      state->ReadDirect(operation);
      return;
    }
    state->portal_connection = connection;
    state->SubscribePortal();
    state->CallPortal(operation);
  }

  static void PortalRead(GObject* source, GAsyncResult* result,
                         gpointer user_data) {
    std::unique_ptr<AsyncContext> context(
        static_cast<AsyncContext*>(user_data));
    auto& state = context->state;
    auto& operation = context->operation;
    g_autoptr(GError) error = nullptr;
    g_autoptr(GVariant) reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (operation->completed || state->disposed) return;
    if (reply == nullptr) {
      state->ReadDirect(operation);
      return;
    }
    state->CompleteOverride(operation, ParsePortalReply(reply));
  }

  static gboolean PortalTimeout(gpointer user_data) {
    auto* context = static_cast<AsyncContext*>(user_data);
    auto& state = context->state;
    auto& operation = context->operation;
    operation->timeout_id = 0;
    if (!operation->completed && !state->disposed) {
      state->ReadDirect(operation);
      g_cancellable_cancel(operation->cancellable);
    }
    return G_SOURCE_REMOVE;
  }

  void StartWatching(ChangeCallback callback) {
    if (disposed) return;
    StopWatching();
    change_callback = std::move(callback);
    SubscribePortal();
    if (direct_settings != nullptr) ConnectDirect();
  }

  void StopWatching() {
    change_callback = nullptr;
    DisconnectWatchers();
  }

  void ConnectDirect() {
    if (direct_settings == nullptr || direct_signal_id != 0) return;
    g_autofree gchar* detailed =
        g_strdup_printf("changed::%s", direct_key.c_str());
    direct_signal_id = g_signal_connect(direct_settings, detailed,
                                        G_CALLBACK(DirectChanged), this);
  }

  void SubscribePortal() {
    if (portal_connection == nullptr || !change_callback ||
        portal_subscription_id != 0) {
      return;
    }
    portal_subscription_id = g_dbus_connection_signal_subscribe(
        portal_connection, kPortalName, kPortalInterface, kPortalChanged,
        kPortalPath, kCalendarNamespace, G_DBUS_SIGNAL_FLAGS_NONE,
        PortalChanged, this, nullptr);
  }

  void DisconnectWatchers() {
    if (direct_settings != nullptr && direct_signal_id != 0) {
      g_signal_handler_disconnect(direct_settings, direct_signal_id);
      direct_signal_id = 0;
    }
    if (portal_connection != nullptr && portal_subscription_id != 0) {
      g_dbus_connection_signal_unsubscribe(portal_connection,
                                           portal_subscription_id);
      portal_subscription_id = 0;
    }
  }

  static void DirectChanged(GSettings*, gchar*, gpointer user_data) {
    auto* state = static_cast<State*>(user_data);
    if (!state->disposed && state->change_callback) state->change_callback();
  }

  static void PortalChanged(GDBusConnection*, const gchar*, const gchar*,
                            const gchar*, const gchar*, GVariant* parameters,
                            gpointer user_data) {
    auto* state = static_cast<State*>(user_data);
    if (state->disposed || !state->change_callback || parameters == nullptr ||
        !g_variant_is_of_type(parameters, G_VARIANT_TYPE("(ssv)"))) {
      return;
    }
    const gchar* name_space = nullptr;
    const gchar* key = nullptr;
    g_autoptr(GVariant) value = nullptr;
    g_variant_get(parameters, "(&s&sv)", &name_space, &key, &value);
    if (g_str_equal(name_space, kCalendarNamespace) &&
        g_str_equal(key, kWeekStartKey)) {
      state->change_callback();
    }
  }

  bool disposed = false;
  GDBusConnection* portal_connection = nullptr;
  GSettingsSchemaSource* schema_source = nullptr;
  GSettings* direct_settings = nullptr;
  std::string direct_schema;
  std::string direct_key;
  LocaleReader locale_reader;
  guint portal_timeout_milliseconds;
  guint portal_subscription_id = 0;
  gulong direct_signal_id = 0;
  ChangeCallback change_callback;
  std::shared_ptr<Operation> active;
};

BusyMaxLinuxFirstWeekdayPreference::BusyMaxLinuxFirstWeekdayPreference()
    : BusyMaxLinuxFirstWeekdayPreference(Configuration{}) {}

BusyMaxLinuxFirstWeekdayPreference::BusyMaxLinuxFirstWeekdayPreference(
    Configuration configuration)
    : state_(std::make_shared<State>(std::move(configuration))) {}

BusyMaxLinuxFirstWeekdayPreference::~BusyMaxLinuxFirstWeekdayPreference() {
  state_->Dispose();
}

void BusyMaxLinuxFirstWeekdayPreference::Read(ReadCallback callback) {
  state_->Read(std::move(callback));
}

void BusyMaxLinuxFirstWeekdayPreference::CancelRead() {
  state_->CancelActive(true);
}

void BusyMaxLinuxFirstWeekdayPreference::StartWatching(
    ChangeCallback callback) {
  state_->StartWatching(std::move(callback));
}

void BusyMaxLinuxFirstWeekdayPreference::StopWatching() {
  state_->StopWatching();
}
