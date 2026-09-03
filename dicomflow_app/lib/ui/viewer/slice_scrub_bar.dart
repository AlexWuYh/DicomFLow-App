import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/slice_index.dart';
import '../theme.dart';

class SliceScrubBar extends StatelessWidget {
  const SliceScrubBar({
    super.key,
    required this.current,
    required this.total,
    required this.playing,
    required this.onChanged,
    required this.onPlayPause,
    this.onStep,
  });

  final int current;
  final int total;
  final bool playing;
  final ValueChanged<int> onChanged;
  final VoidCallback onPlayPause;
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final max = total <= 1 ? 1.0 : total.toDouble();
    final value = current.clamp(1, total <= 0 ? 1 : total).toDouble();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            onStep?.call(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            onStep?.call(1),
        const SingleActivator(LogicalKeyboardKey.space): onPlayPause,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: onPlayPause,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: max,
                    divisions: total <= 1 ? null : total - 1,
                    value: value.clamp(1, max),
                    label: '$current / $total',
                    onChanged: total <= 0
                        ? null
                        : (v) => onChanged(v.round().clamp(1, total)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$current / $total',
                    key: const Key('slice-index-label'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
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

Duration seekPosition({required int slice, required int fps}) {
  return positionForSlice(slice: slice, fps: fps);
}
