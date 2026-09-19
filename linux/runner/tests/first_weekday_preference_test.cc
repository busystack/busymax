#include "../first_weekday_preference.h"

#include <gio/gio.h>

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace {

constexpr char kPortalName[] = "org.freedesktop.portal.Desktop";
constexpr char kPortalPath[] = "/org/freedesktop/portal/desktop";
constexpr char kPortalInterface[] = "org.freedesktop.portal.Settings";
constexpr char kCalendarNamespace[] = "org.gnome.desktop.calendar";
constexpr char kWeekStartKey[] = "week-start-day";

int failures = 0;

void Check(bool condition, const char* description) {
  if (condition) return;
  ++failures;
  std::fprintf(stderr, "FAILED: %s\n", description);
}

bool SpinUntil(const std::function<bool()>& condition,
               std::chrono::milliseconds timeout =
                   std::chrono::milliseconds(2000)) {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (!condition() && std::chrono::steady_clock::now() < deadline) {
    while (g_main_context_iteration(nullptr, FALSE)) {
    }
    g_usleep(1000);
  }
  return condition();
}

std::optional<int> Read(BusyMaxLinuxFirstWeekdayPreference& reader) {
  bool complete = false;
  std::optional<int> result;
  reader.Read([&](std::optional<int> value) {
    result = value;
    complete = true;
  });
  Check(SpinUntil([&] { return complete; }), "weekday read completes");
  return result;
}

GDBusConnection* ConnectToBus(const gchar* address) {
  g_autoptr(GError) error = nullptr;
  GDBusConnection* connection = g_dbus_connection_new_for_address_sync(
      address,
      static_cast<GDBusConnectionFlags>(
          G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT |
          G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION),
      nullptr, nullptr, &error);
  if (connection == nullptr) {
    std::fprintf(stderr, "Private bus connection failed: %s\n",
                 error != nullptr ? error->message : "unknown error");
    std::abort();
  }
  return connection;
}

class PortalService {
 public:
  explicit PortalService(const gchar* address)
      : service_(ConnectToBus(address)), client_(ConnectToBus(address)) {
    g_autoptr(GError) error = nullptr;
    introspection_ = g_dbus_node_info_new_for_xml(
        "<node>"
        " <interface name='org.freedesktop.portal.Settings'>"
        "  <method name='ReadOne'>"
        "   <arg type='s' direction='in'/>"
        "   <arg type='s' direction='in'/>"
        "   <arg type='v' direction='out'/>"
        "  </method>"
        "  <signal name='SettingChanged'>"
        "   <arg type='s'/><arg type='s'/><arg type='v'/>"
        "  </signal>"
        " </interface>"
        "</node>",
        &error);
    if (introspection_ == nullptr) {
      std::fprintf(stderr, "Portal introspection failed: %s\n",
                   error->message);
      std::abort();
    }
  }

  ~PortalService() {
    SetAvailable(false);
    for (auto* invocation : delayed_) {
      g_dbus_method_invocation_return_dbus_error(
          invocation, "org.freedesktop.portal.Error.Failed",
          "Test portal stopped");
    }
    delayed_.clear();
    g_dbus_node_info_unref(introspection_);
    g_dbus_connection_flush_sync(service_, nullptr, nullptr);
    g_dbus_connection_close_sync(client_, nullptr, nullptr);
    g_dbus_connection_close_sync(service_, nullptr, nullptr);
    g_object_unref(client_);
    g_object_unref(service_);
  }

  GDBusConnection* client() const { return client_; }
  void set_value(std::string value) { value_ = std::move(value); }
  void set_delay(bool value) { delay_ = value; }

  void SetAvailable(bool available) {
    if (available == available_) return;
    if (available) {
      static const GDBusInterfaceVTable vtable = {HandleMethod, nullptr,
                                                  nullptr, {0}};
      g_autoptr(GError) error = nullptr;
      registration_id_ = g_dbus_connection_register_object(
          service_, kPortalPath, introspection_->interfaces[0], &vtable, this,
          nullptr, &error);
      Check(registration_id_ != 0, "portal object registers");
      g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
          service_, "org.freedesktop.DBus", "/org/freedesktop/DBus",
          "org.freedesktop.DBus", "RequestName",
          g_variant_new("(su)", kPortalName, 0U), G_VARIANT_TYPE("(u)"),
          G_DBUS_CALL_FLAGS_NONE, 1000, nullptr, &error);
      Check(reply != nullptr, "portal name is owned");
      available_ = reply != nullptr;
      return;
    }
    if (registration_id_ != 0) {
      g_dbus_connection_unregister_object(service_, registration_id_);
      registration_id_ = 0;
    }
    g_autoptr(GError) error = nullptr;
    g_dbus_connection_call_sync(
        service_, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "ReleaseName",
        g_variant_new("(s)", kPortalName), G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE, 1000, nullptr, &error);
    available_ = false;
  }

  void Emit(const char* name_space = kCalendarNamespace,
            const char* key = kWeekStartKey) {
    g_autoptr(GError) error = nullptr;
    const gboolean sent = g_dbus_connection_emit_signal(
        service_, nullptr, kPortalPath, kPortalInterface, "SettingChanged",
        g_variant_new("(ssv)", name_space, key,
                      g_variant_new_string(value_.c_str())),
        &error);
    Check(sent, "portal setting signal emits");
  }

  void FailDelayed() {
    const auto delayed = std::move(delayed_);
    delayed_.clear();
    for (auto* invocation : delayed) {
      g_dbus_method_invocation_return_dbus_error(
          invocation, "org.freedesktop.portal.Error.Failed",
          "Delayed test response");
    }
  }

  int reads() const { return reads_; }
  bool arguments_valid() const { return arguments_valid_; }

 private:
  static void HandleMethod(GDBusConnection*, const gchar*, const gchar*,
                           const gchar*, const gchar* method,
                           GVariant* parameters,
                           GDBusMethodInvocation* invocation,
                           gpointer user_data) {
    auto* self = static_cast<PortalService*>(user_data);
    if (!g_str_equal(method, "ReadOne")) {
      g_dbus_method_invocation_return_dbus_error(
          invocation, "org.freedesktop.DBus.Error.UnknownMethod", method);
      return;
    }
    ++self->reads_;
    const gchar* name_space = nullptr;
    const gchar* key = nullptr;
    g_variant_get(parameters, "(&s&s)", &name_space, &key);
    self->arguments_valid_ =
        self->arguments_valid_ &&
        g_str_equal(name_space, kCalendarNamespace) &&
        g_str_equal(key, kWeekStartKey);
    if (self->delay_) {
      self->delayed_.push_back(
          G_DBUS_METHOD_INVOCATION(g_object_ref(invocation)));
      return;
    }
    g_dbus_method_invocation_return_value(
        invocation,
        g_variant_new("(v)", g_variant_new_string(self->value_.c_str())));
  }

  GDBusConnection* service_;
  GDBusConnection* client_;
  GDBusNodeInfo* introspection_ = nullptr;
  guint registration_id_ = 0;
  bool available_ = false;
  bool delay_ = false;
  bool arguments_valid_ = true;
  int reads_ = 0;
  std::string value_ = "default";
  std::vector<GDBusMethodInvocation*> delayed_;
};

BusyMaxLinuxFirstWeekdayPreference::Configuration Configuration(
    PortalService& portal, GSettingsSchemaSource* schemas,
    std::optional<int> locale = 7) {
  BusyMaxLinuxFirstWeekdayPreference::Configuration configuration;
  configuration.portal_connection = portal.client();
  configuration.schema_source = schemas;
  configuration.locale_reader = [locale] { return locale; };
  configuration.portal_timeout_milliseconds = 100;
  return configuration;
}

GSettings* TestSettings(GSettingsSchemaSource* schemas) {
  GSettingsSchema* schema = g_settings_schema_source_lookup(
      schemas, kCalendarNamespace, TRUE);
  Check(schema != nullptr, "test calendar schema exists");
  GSettings* settings = g_settings_new_full(schema, nullptr, nullptr);
  g_settings_schema_unref(schema);
  return settings;
}

void SetSetting(GSettings* settings, const char* value) {
  Check(g_settings_set_string(settings, kWeekStartKey, value),
        "isolated setting changes");
  g_settings_sync();
  while (g_main_context_iteration(nullptr, FALSE)) {
  }
}

void TestPortalValues(PortalService& portal,
                      GSettingsSchemaSource* schemas) {
  portal.SetAvailable(true);
  BusyMaxLinuxFirstWeekdayPreference reader(Configuration(portal, schemas));
  const std::vector<std::pair<const char*, int>> weekdays = {
      {"monday", 1},   {"tuesday", 2}, {"wednesday", 3},
      {"thursday", 4}, {"friday", 5},  {"saturday", 6},
      {"sunday", 7},
  };
  for (const auto& [value, expected] : weekdays) {
    portal.set_value(value);
    Check(Read(reader) == expected, "portal weekday maps to Dart numbering");
  }
  portal.set_value("default");
  Check(Read(reader) == 7, "portal default uses locale convention");
  portal.set_value("not-a-weekday");
  Check(Read(reader) == 7, "malformed portal value uses locale convention");
  Check(portal.arguments_valid(), "portal receives exact namespace and key");
}

void TestPackagedPortalWins(PortalService& portal,
                            GSettingsSchemaSource* schemas) {
  portal.SetAvailable(true);
  portal.set_value("monday");
  auto configuration = Configuration(portal, schemas, 7);
  configuration.direct_key = "key-not-in-local-schemas";
  BusyMaxLinuxFirstWeekdayPreference reader(std::move(configuration));
  Check(Read(reader) == 1,
        "host portal Monday wins when package-local schema lacks key");
}

void TestDirectAndFallbacks(PortalService& portal,
                            GSettingsSchemaSource* schemas) {
  portal.SetAvailable(false);
  g_autoptr(GSettings) settings = TestSettings(schemas);
  SetSetting(settings, "tuesday");
  BusyMaxLinuxFirstWeekdayPreference direct(Configuration(portal, schemas, 7));
  Check(Read(direct) == 2, "unavailable portal falls back to GSettings");

  auto missing_schema = Configuration(portal, schemas, 4);
  missing_schema.direct_schema = "org.gnome.desktop.missing";
  BusyMaxLinuxFirstWeekdayPreference schema_reader(
      std::move(missing_schema));
  Check(Read(schema_reader) == 4, "missing schema safely uses locale");

  auto missing_key = Configuration(portal, schemas, 5);
  missing_key.direct_key = "missing-key";
  BusyMaxLinuxFirstWeekdayPreference key_reader(std::move(missing_key));
  Check(Read(key_reader) == 5, "missing key safely uses locale");

  SetSetting(settings, "malformed");
  BusyMaxLinuxFirstWeekdayPreference malformed(
      Configuration(portal, schemas, 6));
  Check(Read(malformed) == 6, "malformed direct value uses locale");
  SetSetting(settings, "default");
  Check(Read(malformed) == 6, "direct default uses valid locale fallback");
}

void TestDirectNotifications(PortalService& portal,
                             GSettingsSchemaSource* schemas) {
  portal.SetAvailable(false);
  g_autoptr(GSettings) settings = TestSettings(schemas);
  SetSetting(settings, "monday");
  BusyMaxLinuxFirstWeekdayPreference reader(Configuration(portal, schemas, 6));
  int changes = 0;
  reader.StartWatching([&] { ++changes; });
  Check(Read(reader) == 1, "direct watcher initial read sees Monday");

  SetSetting(settings, "sunday");
  Check(SpinUntil([&] { return changes == 1; }),
        "direct Monday to Sunday emits change");
  Check(Read(reader) == 7, "direct reread sees Sunday");

  SetSetting(settings, "default");
  Check(SpinUntil([&] { return changes == 2; }),
        "direct explicit to default emits change");
  Check(Read(reader) == 6, "direct default rereads locale");

  reader.StopWatching();
  SetSetting(settings, "wednesday");
  Check(changes == 2, "stopped direct subscription emits nothing");
  reader.StartWatching([&] { ++changes; });
  Check(Read(reader) == 3,
        "recreated direct subscription obtains current value");
}

void TestPortalNotifications(PortalService& portal,
                             GSettingsSchemaSource* schemas) {
  portal.SetAvailable(true);
  portal.set_value("monday");
  BusyMaxLinuxFirstWeekdayPreference reader(Configuration(portal, schemas));
  int changes = 0;
  reader.StartWatching([&] { ++changes; });
  Check(Read(reader) == 1, "portal watcher initial read sees Monday");

  portal.Emit(kCalendarNamespace, "unrelated-key");
  SpinUntil([&] { return false; }, std::chrono::milliseconds(20));
  Check(changes == 0, "portal watcher filters unrelated settings");
  portal.set_value("sunday");
  portal.Emit();
  Check(SpinUntil([&] { return changes == 1; }),
        "portal Monday to Sunday emits change");
  Check(Read(reader) == 7, "portal reread sees Sunday");

  reader.StopWatching();
  portal.set_value("wednesday");
  portal.Emit();
  SpinUntil([&] { return false; }, std::chrono::milliseconds(20));
  Check(changes == 1, "stopped portal subscription emits nothing");
  reader.StartWatching([&] { ++changes; });
  Check(Read(reader) == 3,
        "recreated portal subscription obtains current value");
}

void TestBoundedFailureAndDisposal(PortalService& portal,
                                   GSettingsSchemaSource* schemas) {
  portal.SetAvailable(true);
  g_autoptr(GSettings) settings = TestSettings(schemas);
  SetSetting(settings, "wednesday");
  portal.set_delay(true);
  auto bounded_configuration = Configuration(portal, schemas, 6);
  bounded_configuration.portal_timeout_milliseconds = 20;
  BusyMaxLinuxFirstWeekdayPreference bounded(
      std::move(bounded_configuration));
  const auto started = std::chrono::steady_clock::now();
  Check(Read(bounded) == 3,
        "bounded portal failure falls through to current direct value");
  const auto elapsed = std::chrono::steady_clock::now() - started;
  Check(elapsed < std::chrono::milliseconds(500),
        "portal failure remains inside controller timeout budget");
  portal.FailDelayed();
  while (g_main_context_iteration(nullptr, FALSE)) {
  }

  int callbacks = 0;
  const int reads_before_disposal = portal.reads();
  {
    auto reader = std::make_unique<BusyMaxLinuxFirstWeekdayPreference>(
        Configuration(portal, schemas));
    reader->Read([&](std::optional<int>) { ++callbacks; });
    Check(SpinUntil([&] { return portal.reads() > reads_before_disposal; }),
          "delayed disposal read reaches portal");
  }
  portal.FailDelayed();
  SpinUntil([&] { return false; }, std::chrono::milliseconds(20));
  Check(callbacks == 0, "disposed reader suppresses late callback");
  portal.set_delay(false);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 2) {
    std::fprintf(stderr, "Usage: %s COMPILED_SCHEMA_DIRECTORY\n", argv[0]);
    return EXIT_FAILURE;
  }
  g_setenv("GSETTINGS_BACKEND", "memory", TRUE);
  g_autoptr(GError) error = nullptr;
  GSettingsSchemaSource* schemas = g_settings_schema_source_new_from_directory(
      argv[1], nullptr, FALSE, &error);
  if (schemas == nullptr) {
    std::fprintf(stderr, "Test schema load failed: %s\n", error->message);
    return EXIT_FAILURE;
  }

  GTestDBus* bus = g_test_dbus_new(G_TEST_DBUS_NONE);
  g_test_dbus_up(bus);
  {
    PortalService portal(g_test_dbus_get_bus_address(bus));
    TestPortalValues(portal, schemas);
    TestPackagedPortalWins(portal, schemas);
    TestDirectAndFallbacks(portal, schemas);
    TestDirectNotifications(portal, schemas);
    TestPortalNotifications(portal, schemas);
    TestBoundedFailureAndDisposal(portal, schemas);
  }
  g_settings_schema_source_unref(schemas);
  g_test_dbus_down(bus);
  g_object_unref(bus);

  if (failures == 0) {
    std::puts("BusyMax Linux first-weekday preference tests passed.");
  }
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
