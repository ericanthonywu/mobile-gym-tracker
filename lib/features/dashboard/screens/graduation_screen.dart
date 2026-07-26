import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// 🎓 Graduation celebration screen — shown on August 9 when the notification
/// is tapped OR when the dashboard easter egg button is pressed.
class GraduationScreen extends StatefulWidget {
  const GraduationScreen({super.key});

  /// Push a full-screen modal route with a beautiful entrance.
  static Future<void> show(BuildContext context) {
    HapticFeedback.heavyImpact();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const GraduationScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<GraduationScreen> createState() => _GraduationScreenState();
}

class _GraduationScreenState extends State<GraduationScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _glowCtrl;
  late final AnimationController _textCtrl;
  late final List<_ConfettiParticle> _particles;
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(70, (_) => _ConfettiParticle());

    // Infinite confetti via Ticker — real elapsed seconds, never stops
    _ticker = createTicker((duration) {
      setState(() => _elapsed = duration.inMilliseconds / 1000.0);
    });
    _ticker.start();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B16),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0A2E),
                  Color(0xFF0B0B16),
                  Color(0xFF0D1A0A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Confetti layer — infinite loop via Ticker elapsed time
          CustomPaint(
            painter: _ConfettiPainter(_particles, _elapsed),
            size: Size.infinite,
          ),

          // Glowing top stars
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => _buildStarGlow(_glowCtrl.value),
          ),

          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, child) => Opacity(
                opacity: Curves.easeOut.transform(_textCtrl.value),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - Curves.easeOut.transform(_textCtrl.value))),
                  child: child,
                ),
              ),
              child: _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarGlow(double glowValue) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 300,
        child: CustomPaint(
          painter: _StarGlowPainter(glowValue),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 1),

        // Graduation cap emoji with glow ring
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) => _GraduationCapWidget(glowValue: _glowCtrl.value),
        ),
        const SizedBox(height: 20),

        // Main headline
        const Text(
          '🌟 CONGRATULATIONS,\nVIVIAN! 🌟',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'August 9, 2026 — Your Day 🎓',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFFD700),
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        // Compliment card — scrollable
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: _buildComplimentText(context),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Close button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(
                          alpha: 0.2 + 0.2 * _glowCtrl.value),
                      blurRadius: 16 + 8 * _glowCtrl.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  '💛 Thank You, Vivian!',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildComplimentText(BuildContext context) {
    const golden = Color(0xFFFFD700);
    const white = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComplimentParagraph(
          emoji: '🎓',
          text: 'Vivian, today is proof that dreams don\'t stay dreams when you '
              'put in the work. You made it — and not just academically. You showed '
              'up for yourself every single day, in every single way.',
          highlightColor: golden,
        ),
        const SizedBox(height: 20),
        _ComplimentParagraph(
          emoji: '💪',
          text: 'While everyone else was just wishing for change, you were '
              'at the gym, logging your meals, tracking your weight, and pushing '
              'yourself one rep at a time. That discipline? That\'s the real degree '
              'you earned.',
          highlightColor: const Color(0xFF39E57A),
        ),
        const SizedBox(height: 20),
        _ComplimentParagraph(
          emoji: '✨',
          text: 'You are stronger — not just physically, but in your mind and '
              'your spirit. The version of you walking across that stage today is '
              'the result of every early morning, every set completed, every meal '
              'tracked, and every time you chose to show up even when you didn\'t '
              'feel like it.',
          highlightColor: const Color(0xFF6ABAFF),
        ),
        const SizedBox(height: 20),
        _ComplimentParagraph(
          emoji: '🌸',
          text: 'You are radiant. You are capable of anything you set your mind to. '
              'And you proved that this year — to yourself and to everyone around you.',
          highlightColor: const Color(0xFFFF85B3),
        ),
        const SizedBox(height: 20),
        _ComplimentParagraph(
          emoji: '🔥',
          text: 'This isn\'t the end of your journey — it\'s the beginning of an '
              'even bigger chapter. Keep chasing your goals with that same fire. '
              'Keep training. Keep growing. Keep glowing.',
          highlightColor: const Color(0xFFFF6B35),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                golden.withValues(alpha: 0.1),
                const Color(0xFFFF8C00).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: golden.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Text(
                '🏆',
                style: TextStyle(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '"She believed she could, so she did."',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: golden,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Happy Graduation Day, Vivian! 💛',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Personal sign-off from her bf 💕
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF85B3).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF85B3).withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('💌', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                'Love you, your bf',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF85B3),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 10),
              Text('💕', style: TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compliment paragraph with emoji
// ---------------------------------------------------------------------------
class _ComplimentParagraph extends StatelessWidget {
  final String emoji;
  final String text;
  final Color highlightColor;

  const _ComplimentParagraph({
    required this.emoji,
    required this.text,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.65,
              fontFamily: 'Barlow',
            ),
          ),
        ),
        Container(width: 3, height: 60, color: highlightColor.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(left: 10), decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Graduation cap widget
// ---------------------------------------------------------------------------
class _GraduationCapWidget extends StatelessWidget {
  final double glowValue;
  const _GraduationCapWidget({required this.glowValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD700).withValues(alpha: 0.08),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2 + 0.15 * glowValue),
            width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15 + 0.15 * glowValue),
            blurRadius: 30 + 20 * glowValue,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Center(
        child: Text('🎓', style: TextStyle(fontSize: 64)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confetti particle system
// ---------------------------------------------------------------------------
class _ConfettiParticle {
  late double x;
  late double y;
  late double speed;
  late double angle;
  late double size;
  late Color color;
  late double rotation;
  late double rotationSpeed;

  static final _rng = Random();
  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFFF6B9D),
    Color(0xFF39E57A),
    Color(0xFF6ABAFF),
    Color(0xFFFF8C00),
    Color(0xFFE040FB),
    Color(0xFFFFF176),
  ];

  _ConfettiParticle() {
    reset(initial: true);
  }

  void reset({bool initial = false}) {
    x = _rng.nextDouble();
    y = initial ? _rng.nextDouble() : -0.05;
    speed = 0.04 + _rng.nextDouble() * 0.06;
    angle = -0.3 + _rng.nextDouble() * 0.6;
    size = 4 + _rng.nextDouble() * 8;
    color = _colors[_rng.nextInt(_colors.length)];
    rotation = _rng.nextDouble() * pi * 2;
    rotationSpeed = (-1 + _rng.nextDouble() * 2) * 3;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double elapsed; // seconds, increases monotonically

  _ConfettiPainter(this.particles, this.elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // y advances at p.speed units/sec; wraps at 1.2 so it re-enters from top
      final currentY = (p.y + p.speed * elapsed) % 1.2;
      final currentX = p.x + sin(elapsed * 1.5 + p.y * 10) * 0.025 * p.angle;
      final currentRot = p.rotation + p.rotationSpeed * elapsed;

      // Fade out gently as particle nears bottom
      final alpha = currentY < 1.0 ? 1.0 : (1.2 - currentY) / 0.2;

      final paint = Paint()
        ..color = p.color.withValues(alpha: (alpha * 0.85).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX * size.width, currentY * size.height);
      canvas.rotate(currentRot);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.elapsed != elapsed;
}

// ---------------------------------------------------------------------------
// Star glow painter
// ---------------------------------------------------------------------------
class _StarGlowPainter extends CustomPainter {
  final double glow;
  _StarGlowPainter(this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.08 + 0.04 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, 0),
        radius: size.height,
      ));
    canvas.drawCircle(Offset(size.width / 2, 0), size.height, paint);
  }

  @override
  bool shouldRepaint(_StarGlowPainter old) => old.glow != glow;
}
