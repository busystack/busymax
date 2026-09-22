# Linux window and rendering ownership

BusyMax uses one Flutter engine and one `FlView` in its main Linux window. The
native runner creates and owns the `HdyApplicationWindow`, while Flutter owns
the visible main application chrome: the header, sidebar, calendar/task
workspace, settings header, onboarding header, and startup header.

`LinuxWindowHost` is the Linux-only boundary around the existing router. It
tracks native window state and GTK titlebar preferences and presents only the
configured system-window controls above route dialog barriers. It does not
own page widgets or sidebar geometry. `LinuxPageFrame` is the reusable route
frame. Its leading child is one clipped, full-height allocation containing
both the sidebar header and body; one controller changes that allocation, and
the remaining column receives the actual remaining width.

The GTK runner retains platform responsibilities that do not belong in the
Flutter layout: application identity and lifecycle, close-versus-quit policy,
deferred first-frame presentation, plugin registration, native menus and
pickers, retained native dialogs, external file/URI activation, GTK desktop
settings, and native-surface styling. Native surface styling is independent
of main-header existence. GTK window-decoration layout and titlebar-action
preferences are exposed as settings events, not as per-frame geometry
synchronization.

Windows and Android keep their existing platform-specific application roots
and window-management compositions. Linux-only imports and Yaru window
initialization remain in the Linux entrypoint and Linux application root.
