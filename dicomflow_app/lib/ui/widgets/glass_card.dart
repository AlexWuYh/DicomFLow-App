import 'package:flutter/material.dart';

import '../theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.muted = false,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final bool muted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.glass.withValues(alpha: muted ? 0.5 : 0.72),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: tokens.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: box,
    );
  }
}

class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.label, this.done = false});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: done ? '已完成' : '步骤 $label',
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: done
                ? const [Color(0xFF00A544), Color(0xFF05DF72)]
                : const [AppColors.primary, AppColors.primaryLight],
          ),
          boxShadow: [
            BoxShadow(
              color: (done ? const Color(0xFF00A544) : AppColors.primary)
                  .withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.muted,
        ),
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  const FeatureChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.glass,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.glassBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
