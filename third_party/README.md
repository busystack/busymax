# Vendored dependencies

BusyMax overrides four packages with source under `third_party/`. Their
upstream license files and notices remain authoritative and must stay intact.

| Package | Upstream/version | Local path | License | Why it is vendored |
|---|---|---|---|---|
| `flutter_timezone` | [tjarvstrand/flutter_timezone](https://github.com/tjarvstrand/flutter_timezone), 5.1.0 | [`third_party/flutter_timezone`](flutter_timezone/) | [Apache-2.0](flutter_timezone/LICENSE) | Keep the upstream Dart API and Windows plugin without registering another Linux timezone implementation |
| `tray_manager` | [leanflutter/tray_manager](https://github.com/leanflutter/tray_manager), 0.5.3 | [`third_party/tray_manager`](tray_manager/) | [MIT](tray_manager/LICENSE) | Keep the upstream Dart API and Windows tray plugin while Linux continues to use BusyMax's XDG/DBus tray |
| `yaru_window` | [ubuntu/yaru_window.dart](https://github.com/ubuntu/yaru_window.dart), 0.2.2 | [`third_party/yaru_window`](yaru_window/) | [MPL-2.0](yaru_window/LICENSE) | Restrict plugin registration to Linux so the Windows runner remains the sole Windows lifecycle owner |
| `xdg_status_notifier_item` | [canonical/xdg_status_notifier_item.dart](https://github.com/canonical/xdg_status_notifier_item.dart), 0.0.1 | [`third_party/xdg_status_notifier_item`](xdg_status_notifier_item/) | [MPL-2.0](xdg_status_notifier_item/LICENSE) | Provide the Linux StatusNotifierItem and DBusMenu behavior BusyMax needs beyond the published package |

BusyMax-specific notes for the platform-scoped package copies are in:

- [flutter_timezone vendoring notes](flutter_timezone/README.busymax.md)
- [tray_manager vendoring notes](tray_manager/README.busymax.md)
- [yaru_window vendoring notes](yaru_window/README.busymax.md)

## XDG StatusNotifierItem changes

The vendored XDG package keeps its upstream
[README](xdg_status_notifier_item/README.md),
[CHANGELOG](xdg_status_notifier_item/CHANGELOG.md), and
[contribution guide](xdg_status_notifier_item/CONTRIBUTING.md) unchanged.

BusyMax's local patches:

- widen the Dart SDK constraint for Dart 3;
- export DBusMenu at the tray menu path and support explicit stable item IDs;
- implement DBusMenu group-property and menu-object properties;
- support both KDE and freedesktop StatusNotifierItem interfaces;
- correct callback argument handling for coordinates, scroll deltas, and
  orientation;
- expose item/menu paths, `ItemIsMenu`, and diagnostic logging hooks;
- emit standard title, icon, and tooltip update signals; and
- correct the tooltip signature and expose accessible title/description text.

MPL-2.0-covered source and local modifications remain under MPL-2.0. Preserve
the package's upstream license and notices when redistributing it.
