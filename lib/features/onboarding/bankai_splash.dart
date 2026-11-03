import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Glad logo reveal used by onboarding and the Appearance preview.
///
/// [progress] runs 0 → 1: the logo scales up with a soft overshoot, fades in
/// and its glow blooms. Same API the splash has always had, so callers did not
/// have to change when the artwork did. The artwork is `assets/icon/logo_mark.png`,
/// regenerated from `assets/brand/glad_logo.png` by `tool/apply_glad_logo.py`.
class BankaiSplash extends StatelessWidget {
  const BankaiSplash({super.key, required this.progress, this.size = 220});

  /// 0 → 1.
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0).toDouble();
    final grow = Curves.easeOutBack.transform((t / 0.6).clamp(0.0, 1.0).toDouble());
    final fade = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0).toDouble());
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.55 + 0.45 * grow,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45 * fade),
                    blurRadius: size * 0.35 * fade,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.22),
                child: Image.asset(
                  'assets/icon/logo_mark.png',
                  width: size * 0.8,
                  height: size * 0.8,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
