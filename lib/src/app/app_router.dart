import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/schedule/presentation/schedule_workspace.dart';
import '../schedule/schedule_scope.dart';
import 'app_bootstrap.dart';
import 'busymax_design.dart';
import 'busymax_layout.dart';
import 'busymax_surface_colors.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionControllerProvider);
  final hasSubscriptions =
      ref.watch(webCalSubscriptionsProvider).valueOrNull?.isNotEmpty == true;
  final canOpenSchedule = session.isSignedIn || hasSubscriptions;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: session.status == AuthSessionStatus.loading
        ? '/'
        : canOpenSchedule
        ? '/schedule'
        : '/sign-in',
    redirect: (context, state) {
      if (session.status == AuthSessionStatus.loading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      if (state.matchedLocation == '/') {
        return canOpenSchedule ? '/schedule' : '/sign-in';
      }

      if (!canOpenSchedule &&
          state.matchedLocation != '/sign-in' &&
          state.matchedLocation != '/settings') {
        return '/sign-in';
      }

      if (canOpenSchedule && state.matchedLocation == '/sign-in') {
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
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
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
          if (!BusyMaxLayoutRules.showSidebar(constraints.maxWidth)) {
            return content;
          }
          return Row(
            children: [
              const SizedBox(
                key: ValueKey('startup-sidebar'),
                width: BusyMaxSizes.sidebarWidth,
                child: BusyMaxSidebarSurface(child: SizedBox.expand()),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}
