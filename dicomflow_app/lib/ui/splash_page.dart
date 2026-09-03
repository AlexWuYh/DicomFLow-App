import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/brand_mark.dart';

/// Branded cold-start screen. Shown 1–2s then replaced by the app shell.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DicomFlow 启动中',
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF071433),
                Color(0xFF123A8A),
                AppColors.primary,
              ],
              stops: [0.0, 0.52, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 88),
                  const SizedBox(height: 22),
                  Text(
                    'DicomFlow',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '影像随手看',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xD9FFFFFF),
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SliceMotif(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliceMotif extends StatelessWidget {
  const _SliceMotif();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '切片示意',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 18,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withValues(alpha: 0.18 + i * 0.12),
                border: Border.all(color: const Color(0x66FFFFFF)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
