import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Branded Splash Screen featuring the cute Vivian Gym V logo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends SplashScreenStateClass {
  // Logic class inherits State
}

abstract class SplashScreenStateClass extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController ctrl;
  late Animation<double> scaleAnim;
  late Animation<double> fadeAnim;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );

    fadeAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cute Gym V Logo with pulsing animation
            ScaleTransition(
              scale: scaleAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/v_logo.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "VIVIAN'S",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
            ),
            Text(
              'GYM TRACKER',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 6,
                  ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
