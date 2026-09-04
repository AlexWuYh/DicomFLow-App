import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/pipeline.dart';
import '../../share/result_actions.dart';

/// Always-visible share / export actions for the convert result surface.
class ResultActionBar extends StatelessWidget {
  const ResultActionBar({
    super.key,
    required this.selected,
    required this.allFiles,
    this.sourceFilename,
    this.compact = false,
  });

  final SeriesArtifact selected;
  final List<File> allFiles;
  final String? sourceFilename;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final exists = selected.file.existsSync();
    const shareHint = '只分享正在预览的文件，不是全部结果';
    final shareButton = FilledButton.icon(
      onPressed: !exists ? null : () => runFileAction(context, () => shareMediaFile(selected.file)),
      icon: const Icon(Icons.share, size: 18),
      label: const Text('分享此文件'),
    );
    final share = Tooltip(message: shareHint, child: shareButton);
    final export = Tooltip(
      message: '把全部结果打成一个 zip 保存到所选文件夹',
      child: OutlinedButton.icon(
        onPressed: allFiles.every((f) => !f.existsSync())
            ? null
            : () => exportOutputFilesWithFeedback(
                context,
                allFiles,
                sourceFilename: sourceFilename,
              ),
        icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
        label: const Text('导出到文件夹'),
      ),
    );
    // Phone/Android already has share (this file) + export (all as zip).
    // A third save/download control looks like the same action.
    final reveal = Platform.isAndroid || compact
        ? null
        : OutlinedButton(
            onPressed: !exists ? null : () => runFileAction(context, () => saveOrRevealFile(selected.file)),
            child: const Text('在文件夹中显示'),
          );
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(shareHint, style: hintStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: share),
                const SizedBox(width: 8),
                Expanded(child: export),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          share,
          const SizedBox(height: 6),
          Text(shareHint, style: hintStyle),
          const SizedBox(height: 12),
          export,
          if (reveal != null) ...[
            const SizedBox(height: 8),
            reveal,
          ],
        ],
      ),
    );
  }
}
