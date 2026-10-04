import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/schedule/presentation/schedule_workspace.dart';
import '../schedule/schedule_scope.dart';
import 'app_bootstrap.dart';
import 'busymax_design.dart';
import 'busymax_layout.dart';
import 'busymax_surface_colors.dart';
import 'linux/linux_page_frame.dart';
import 'linux/linux_window_host.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authSessionControllerProvider, (_, _) {
    refreshNotifier.refresh();
  });
  // Listening above also starts session loading and authorization recovery.
  // Keep the router stable while initialization completes.
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refreshNotifier,
    initialLocation: '/',
    redirect: (context, state) {
      if (state.matchedLocation == '/' &&
          ref.read(authSessionControllerProvider).status !=
              AuthSessionStatus.loading) {
        return '/schedule';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const BusyMaxStartupView(),
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleWorkspace(),
      ),
      GoRoute(
        path: '/tasks',
        pageBuilder: (context, state) => _tasksWorkspacePage(),
      ),
      GoRoute(
        path: r'/tasks/:taskRoute(.*)',
        redirect: (context, state) {
          final segmentCount = state.uri.pathSegments.length;
          return segmentCount == 3 || segmentCount == 4 ? null : '/tasks';
        },
        pageBuilder: (context, state) {
          final segments = state.uri.pathSegments;
          return _tasksWorkspacePage(
            accountId: segments[1],
            taskListId: segments[2],
            taskId: segments.length == 4 ? segments[3] : null,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: SettingsScreen(
            initialPage: settingsPageFromRouteValue(
              state.uri.queryParameters['page'],
            ),
          ),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

const _tasksWorkspacePageKey = ValueKey('tasks-workspace');

Page<void> _tasksWorkspacePage({
  String? accountId,
  String? taskListId,
  String? taskId,
}) {
  return NoTransitionPage<void>(
    key: _tasksWorkspacePageKey,
    child: ScheduleWorkspace(
      initialScope: ScheduleScope.tasks,
      initialTaskAccountId: accountId,
      initialTaskListId: taskListId,
      initialTaskId: taskId,
    ),
  );
}

class BusyMaxStartupView extends StatelessWidget {
  const BusyMaxStartupView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return Scaffold(
      backgroundColor: colors.window,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = ColoredBox(
            key: const ValueKey('startup-content'),
            color: colors.window,
            child: const Center(child: YaruCircularProgressIndicator()),
          );
          return LinuxPageFrame(
            header: const LinuxTitlebarGestureRegion(child: SizedBox.expand()),
            body: content,
            sidebarHeader: const BusyMaxLinuxBrandHeader(),
            sidebarBody: const BusyMaxSidebarSurface(
              key: ValueKey('startup-sidebar'),
              showEndBorder: false,
              child: SizedBox.expand(),
            ),
            sidebarAvailable: BusyMaxLayoutRules.showSidebar(
              constraints.maxWidth,
            ),
            sidebarExpanded: true,
          );
        },
      ),
    );
  }
}
