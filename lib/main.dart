import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/router/app_router.dart';
import 'package:gym_tracker/core/theme/app_theme.dart';
import 'package:gym_tracker/core/utils/notification_service.dart';
import 'package:gym_tracker/features/dashboard/screens/graduation_screen.dart';

/// Global navigator key — used to push GraduationScreen from notification taps.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env configuration
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  // Lock to portrait only on iPhone
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Initialize notification service
  await NotificationService.initialize();
  await NotificationService.requestPermission();
  await NotificationService.scheduleDailyReminders();

  // Wire up graduation notification tap → open GraduationScreen
  NotificationService.onGraduationTap = () {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      GraduationScreen.show(ctx);
    }
  };

  runApp(const ProviderScope(child: GymTrackerApp()));
}

class GymTrackerApp extends ConsumerWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: "Vivian's Gym Tracker",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
