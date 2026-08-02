import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';


/// Bottom sheet that shows exercise form photos (image_url_0 → image_url_1)
/// plus muscle targets, equipment, level, and instructions.
///
/// Usage:
///   showExerciseFormPreview(context, activity);
void showExerciseFormPreview(BuildContext context, MasterActivityModel activity) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseFormSheet(activity: activity),
  );
}

class _ExerciseFormSheet extends StatefulWidget {
  final MasterActivityModel activity;
  const _ExerciseFormSheet({required this.activity});

  @override
  State<_ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<_ExerciseFormSheet>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final images = [
      if (activity.imageUrl0 != null && activity.imageUrl0!.isNotEmpty) activity.imageUrl0!,
      if (activity.imageUrl1 != null && activity.imageUrl1!.isNotEmpty) activity.imageUrl1!,
    ];
    final hasImages = images.isNotEmpty;
    final primaryMuscles = activity.primaryMuscles;
    final secondaryMuscles = activity.secondaryMuscles;
    final hasInstructions = activity.instructions.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnim,
      child: DraggableScrollableSheet(
        initialChildSize: hasImages ? 0.78 : 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.name,
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Meta badges row (category, level, equipment) ──
              if (activity.category != null ||
                  activity.level != null ||
                  activity.equipment != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (activity.category != null)
                          _MetaBadge(label: activity.category!, color: AppColors.primary),
                        if (activity.level != null)
                          _MetaBadge(
                            label: activity.level!,
                            color: _levelColor(activity.level!),
                          ),
                        if (activity.equipment != null)
                          _MetaBadge(
                            label: activity.equipment!,
                            color: AppColors.textSecondary,
                            icon: Icons.fitness_center_rounded,
                          ),
                        if (activity.mechanic != null)
                          _MetaBadge(label: activity.mechanic!, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    // ── Form Images ──
                    if (hasImages) ...[
                      // Image Pager
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 220,
                          child: PageView.builder(
                            controller: _pageCtrl,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            itemCount: images.length,
                            itemBuilder: (_, i) => _FormImage(
                              url: images[i],
                              label: i == 0 ? 'START' : 'FINISH',
                              allImages: images,
                              index: i,
                            ),
                          ),
                        ),
                      ),

                      // Page dots + labels
                      if (images.length > 1) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => GestureDetector(
                              onTap: () => _pageCtrl.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentPage == i ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == i
                                      ? AppColors.primary
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            _currentPage == 0 ? '← Swipe for finish position' : 'Start position →',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // ── Muscles ──
                    if (primaryMuscles.isNotEmpty || secondaryMuscles.isNotEmpty) ...[
                      _SectionLabel('Target Muscles'),
                      const SizedBox(height: 8),
                      if (primaryMuscles.isNotEmpty) ...[
                        const Text(
                          'PRIMARY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDisabled,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: primaryMuscles
                              .map((m) => _MuscleBadge(name: m.displayName, isPrimary: true))
                              .toList(),
                        ),
                      ],
                      if (secondaryMuscles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'SECONDARY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDisabled,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: secondaryMuscles
                              .map((m) => _MuscleBadge(name: m.displayName, isPrimary: false))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // ── Instructions ──
                    if (hasInstructions) ...[
                      _SectionLabel('Instructions'),
                      const SizedBox(height: 10),
                      ...activity.instructions.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${e.key + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4CAF50);
      case 'intermediate':
        return const Color(0xFFF97316);
      case 'expert':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSecondary;
    }
  }
}

// =============================================================================
// Lightbox — full-screen image gallery with pinch-to-zoom
// =============================================================================

/// Opens the full-screen lightbox starting at [initialPage].
void _showImageLightbox(BuildContext context, List<String> images, int initialPage) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ImageLightbox(images: images, initialPage: initialPage),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 220),
    ),
  );
}

class _ImageLightbox extends StatefulWidget {
  final List<String> images;
  final int initialPage;
  const _ImageLightbox({required this.images, required this.initialPage});

  @override
  State<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<_ImageLightbox> {
  late final PageController _ctrl;
  int _page = 0;

  // Swipe-down-to-dismiss tracking
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _ctrl = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _labels = ['START', 'FINISH'];

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    // Only track downward drags
    if (d.delta.dy > 0 || _dragY > 0) {
      setState(() {
        _dragY = (_dragY + d.delta.dy).clamp(0.0, double.infinity);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (velocity > 400 || _dragY > 120) {
      Navigator.pop(context);
    } else {
      // Snap back
      setState(() => _dragY = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fade out as the user drags down
    final opacity = (1.0 - _dragY / 280).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withAlpha((_dragY == 0 ? 220 : (220 * opacity).round())),
      body: Transform.translate(
        offset: Offset(0, _dragY),
        child: Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              // ── Full-screen page gallery ──
              PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: widget.images.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    onVerticalDragCancel: () => setState(() => _dragY = 0),
                    child: InteractiveViewer(
                      minScale: 1.0,   // don't allow shrink — keeps drag falling through
                      maxScale: 5.0,
                      panEnabled: true,
                      child: SizedBox.expand(
                        child: CachedNetworkImage(
                          imageUrl: widget.images[i],
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Close button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),

              // ── Page label (START / FINISH) ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                left: 0,
                right: 56,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _page < _labels.length ? _labels[_page] : '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Dot indicators ──
              if (widget.images.length > 1)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _page == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == i ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Hint ──
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 6,
                left: 0,
                right: 0,
                child: const IgnorePointer(
                  child: Center(
                    child: Text(
                      'Tap or swipe down to close  •  Pinch to zoom',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _FormImage extends StatelessWidget {
  final String url;
  final String label;
  final List<String> allImages;
  final int index;
  const _FormImage({
    required this.url,
    required this.label,
    required this.allImages,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageLightbox(context, allImages, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark background so contain-fit letterboxing looks clean
          Container(color: const Color(0xFF1A1A2E)),
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,   // ← no more stretching
            memCacheWidth: 480,
            memCacheHeight: 480,
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (_, __) => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, color: AppColors.textDisabled, size: 32),
                  SizedBox(height: 6),
                  Text('No image', style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Label badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          // Tap-to-expand hint icon
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.open_in_full_rounded, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MetaBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleBadge extends StatelessWidget {
  final String name;
  final bool isPrimary;
  const _MuscleBadge({required this.name, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryMuted : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? AppColors.primary.withAlpha(77) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

/// Inline form image widget for the active session header.
/// Shows image_url_0 then image_url_1 side by side (or single).
class ExerciseFormImages extends StatefulWidget {
  final MasterActivityModel activity;
  final double height;

  const ExerciseFormImages({
    super.key,
    required this.activity,
    this.height = 160,
  });

  @override
  State<ExerciseFormImages> createState() => _ExerciseFormImagesState();
}

class _ExerciseFormImagesState extends State<ExerciseFormImages> {
  late final PageController _ctrl;
  int _page = 0;
  // Auto-flip timer
  bool _autoPlaying = true;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _scheduleFlip();
  }

  void _scheduleFlip() async {
    final images = _images();
    if (images.length < 2) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || !_autoPlaying) return;
    _ctrl.animateToPage(
      1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  List<String> _images() {
    final a = widget.activity;
    return [
      if (a.imageUrl0 != null && a.imageUrl0!.isNotEmpty) a.imageUrl0!,
      if (a.imageUrl1 != null && a.imageUrl1!.isNotEmpty) a.imageUrl1!,
    ];
  }

  @override
  void dispose() {
    _autoPlaying = false;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images();
    if (images.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: images.length,
              itemBuilder: (_, i) => _FormImage(
                url: images[i],
                label: i == 0 ? 'START' : 'FINISH',
                allImages: images,
                index: i,
              ),
            ),
            // Dot indicators
            if (images.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => GestureDetector(
                      onTap: () {
                        _autoPlaying = false;
                        _ctrl.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _page == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
