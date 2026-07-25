import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/auth/providers/auth_provider.dart';

/// PIN login screen — numeric keypad, same UX feel as existing app.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final List<String> _pin = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin.add(digit);
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _onDelete() {
    if (_pin.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _pin.removeLast());
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });
    final pin = _pin.join();
    final error = await ref.read(authProvider.notifier).login(pin);

    if (!mounted) return;

    if (error != null) {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      setState(() {
        _error = 'Wrong PIN. Try again!';
        _pin.clear();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Cute V Logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/v_logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                "VIVIAN'S",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'GYM TRACKER',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(width: 40, height: 3, decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              )),
              const Spacer(flex: 1),
              Text('Enter your PIN', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),

              // PIN dots with shake animation
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    _shakeAnim.value == 0 ? 0 : ((_shakeAnim.value * 10) % 2 == 0 ? 10 : -10) * _shakeCtrl.value,
                    0,
                  ),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: filled ? AppColors.primary : AppColors.border,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Barlow')),
              ],

              const Spacer(flex: 2),

              // Keypad
              _buildKeypad(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) => _buildKey(key)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty) return const SizedBox(width: 80, height: 80);

    final isDelete = key == '⌫';
    return GestureDetector(
      onTap: () => isDelete ? _onDelete() : _onDigit(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDelete ? Colors.transparent : AppColors.surfaceCard,
          border: isDelete ? null : Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: isDelete
            ? const Icon(Icons.backspace_outlined, color: AppColors.textSecondary, size: 22)
            : Text(
                key,
                style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}
