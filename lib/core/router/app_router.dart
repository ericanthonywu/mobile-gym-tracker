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
import 'package:gym_tracker/features/meals/screens/meals_screen.dart';
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

      // Main shell with 4 tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/workout', builder: (_, __) => const WorkoutScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/weight', builder: (_, __) => const WeightScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/meals', builder: (_, __) => const MealsScreen()),
          ]),
        ],
      ),
    ],
  );
});
