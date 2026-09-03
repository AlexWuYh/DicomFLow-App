import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Soft blue/orange blobs matching the web `.aurora` layer.
/// Static in M0 (no infinite ticker) so widget tests can pump without hanging.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: CustomPaint(
            painter: _BlobPainter(isDark: isDark),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    blob(
      Offset(size.width * 0.45, size.height * -0.02),
      size.shortestSide * 0.55,
      const Color(0xFF2563EB).withValues(alpha: isDark ? 0.28 : 0.22),
    );
    blob(
      Offset(size.width * 1.02, size.height * 0.42),
      size.shortestSide * 0.42,
      const Color(0xFFF97316).withValues(alpha: isDark ? 0.16 : 0.14),
    );
    blob(
      Offset(size.width * -0.05, size.height * 0.95),
      size.shortestSide * 0.48,
      const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.14 : 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
