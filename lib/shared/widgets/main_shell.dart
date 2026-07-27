import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Main scaffold with 4-tab bottom nav and slide+fade transition between tabs.
class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _goingForward = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 270));
    _slideAnim = const AlwaysStoppedAnimation(Offset.zero);
    _fadeAnim = const AlwaysStoppedAnimation(1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _resetAnims({required bool forward}) {
    _slideAnim = Tween<Offset>(
      begin: Offset(forward ? 0.1 : -0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  void _switchTo(int newIndex) {
    final current = widget.navigationShell.currentIndex;
    if (newIndex == current) return;
    _goingForward = newIndex > current;
    _resetAnims(forward: _goingForward);
    widget.navigationShell.goBranch(newIndex, initialLocation: newIndex == current);
    _ctrl..reset()..forward();
  }

  void _onNavTap(int index) {
    HapticFeedback.selectionClick();
    _switchTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -350 && currentIndex < 4) { HapticFeedback.selectionClick(); _switchTo(currentIndex + 1); }
          else if (v > 350 && currentIndex > 0) { HapticFeedback.selectionClick(); _switchTo(currentIndex - 1); }
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => SlideTransition(
            position: _slideAnim,
            child: FadeTransition(opacity: _fadeAnim, child: child),
          ),
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 1 ? Icons.fitness_center_rounded : Icons.fitness_center_outlined),
              label: 'Workout',
            ),
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 2 ? Icons.monitor_weight_rounded : Icons.monitor_weight_outlined),
              label: 'Weight',
            ),
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 3 ? Icons.calendar_month_rounded : Icons.calendar_month_outlined),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 4 ? Icons.more_horiz_rounded : Icons.more_horiz_outlined),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
