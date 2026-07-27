import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/features/auth/providers/auth_provider.dart';
import 'package:gym_tracker/features/auth/screens/login_screen.dart';
import 'package:gym_tracker/features/auth/screens/splash_screen.dart';
import 'package:gym_tracker/features/dashboard/screens/dashboard_screen.dart';
import 'package:gym_tracker/features/workout/screens/workout_screen.dart';
import 'package:gym_tracker/features/workout/screens/plan_editor_screen.dart';
import 'package:gym_tracker/features/workout/screens/schedule_editor_screen.dart';
import 'package:gym_tracker/features/workout/screens/active_session_screen.dart';
import 'package:gym_tracker/features/workout/screens/session_detail_screen.dart';
import 'package:gym_tracker/features/weight/screens/weight_screen.dart';
import 'package:gym_tracker/features/workout/screens/calendar_screen.dart';
import 'package:gym_tracker/features/workout/screens/history_list_screen.dart';
import 'package:gym_tracker/features/workout/screens/exercise_stats_screen.dart';
import 'package:gym_tracker/features/menstruation/screens/menstruation_screen.dart';
import 'package:gym_tracker/features/more/screens/more_screen.dart';
import 'package:gym_tracker/shared/widgets/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final status = authState.status;
      final isUnknown = status == AuthStatus.unknown;
      final isAuthenticated = status == AuthStatus.authenticated;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';

      if (isUnknown) return isSplash ? null : '/splash';
      if (isSplash) return isAuthenticated ? '/' : '/login';
      if (!isAuthenticated && !isLogin) return '/login';
      if (isAuthenticated && isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // Plan editor (create new)
      GoRoute(
        path: '/plan/new',
        builder: (_, __) => const PlanEditorScreen(),
      ),
      // Plan editor (edit existing)
      GoRoute(
        path: '/plan/:id/edit',
        builder: (context, state) => PlanEditorScreen(planId: state.pathParameters['id']),
      ),
      // Schedule editor
      GoRoute(
        path: '/schedule/edit',
        builder: (_, __) => const ScheduleEditorScreen(),
      ),
      // Active session
      GoRoute(
        path: '/session/active',
        builder: (_, __) => const ActiveSessionScreen(),
      ),
      // Session detail (history)
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      // Sub-screens from More tab
      GoRoute(
        path: '/history',
        builder: (_, __) => const HistoryListScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (_, __) => const ExerciseStatsScreen(),
      ),
      GoRoute(
        path: '/menstruation',
        builder: (_, __) => const MenstruationScreen(),
      ),

      // Main shell with 5 tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/workout',
              builder: (context, state) {
                final tabStr = state.uri.queryParameters['tab'];
                final tab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
                return WorkoutScreen(initialTabIndex: tab);
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/weight', builder: (_, __) => const WeightScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
          ]),
        ],
      ),
    ],
  );
});
