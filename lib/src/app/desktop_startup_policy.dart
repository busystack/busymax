import 'app_settings.dart';

/// The launch argument keeps a hidden startup reachable until the user changes
/// tray preferences. Window presentation is decided only once per session.
class DesktopStartupPolicy {
  DesktopStartupPolicy({required bool startMinimizedAtLaunch})
    : _launchTrayOverride = startMinimizedAtLaunch;

  bool _launchTrayOverride;
  bool _startupHandled = false;
  (bool, bool, bool)? _previousTrayPreferences;

  bool needsTray(AppSettings settings) {
    final preferences = (
      settings.showTrayIcon,
      settings.runInBackgroundWhenClosed,
      settings.startMinimizedToTray,
    );
    if (_previousTrayPreferences != null &&
        _previousTrayPreferences != preferences) {
      _launchTrayOverride = false;
    }
    _previousTrayPreferences = preferences;
    return settings.showTrayIcon ||
        settings.runInBackgroundWhenClosed ||
        settings.startMinimizedToTray ||
        _launchTrayOverride;
  }

  bool takeStartMinimized(AppSettings settings) {
    if (_startupHandled) return false;
    _startupHandled = true;
    return _launchTrayOverride || settings.startMinimizedToTray;
  }
}
