import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/schedule/presentation/schedule_workspace.dart';
import '../schedule/schedule_scope.dart';
import 'app_bootstrap.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: session.status == AuthSessionStatus.loading
        ? '/'
        : session.isSignedIn
        ? '/schedule'
        : '/sign-in',
    redirect: (context, state) {
      if (session.status == AuthSessionStatus.loading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      if (state.matchedLocation == '/') {
        return session.isSignedIn ? '/schedule' : '/sign-in';
      }

      if (!session.isSignedIn && state.matchedLocation != '/sign-in') {
        return '/sign-in';
      }

      if (session.isSignedIn &&
          session.status == AuthSessionStatus.signedIn &&
          state.matchedLocation == '/sign-in') {
        return '/schedule';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
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
        builder: (context, state) => SettingsScreen(
          initialPage: settingsPageFromRouteValue(
            state.uri.queryParameters['page'],
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
