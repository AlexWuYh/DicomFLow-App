import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact native flow: pick → convert → preview/export. Not a marketing hero.
class ConvertStepsGuide extends StatelessWidget {
  const ConvertStepsGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Text(
              '转换流程',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.muted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: _StepNode(
                    index: '1',
                    icon: Icons.folder_zip_outlined,
                    label: '选压缩包',
                  ),
                ),
                _StepArrow(),
                Expanded(
                  child: _StepNode(
                    index: '2',
                    icon: Icons.movie_creation_outlined,
                    label: '本机转换',
                  ),
                ),
                _StepArrow(),
                Expanded(
                  child: _StepNode(
                    index: '3',
                    icon: Icons.ios_share_outlined,
                    label: '预览导出',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 16,
        color: DicomFlowTokens.of(context).muted2,
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.icon,
    required this.label,
  });

  final String index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.accent],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$index  $label',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: tokens.muted,
          ),
        ),
      ],
    );
  }
}
