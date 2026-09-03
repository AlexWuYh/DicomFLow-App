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
    final share = FilledButton.icon(
      onPressed: !exists ? null : () => runFileAction(context, () => shareMediaFile(selected.file)),
      icon: const Icon(Icons.share, size: 18),
      label: Text(Platform.isAndroid ? '分享给医生' : '分享'),
    );
    final export = OutlinedButton.icon(
      onPressed: allFiles.every((f) => !f.existsSync())
          ? null
          : () => exportOutputFilesWithFeedback(
              context,
              allFiles,
              sourceFilename: sourceFilename,
            ),
      icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
      label: const Text('导出到文件夹'),
    );
    final reveal = compact
        ? IconButton(
            tooltip: Platform.isAndroid ? '保存到文件' : '在文件夹中显示',
            onPressed: !exists ? null : () => runFileAction(context, () => saveOrRevealFile(selected.file)),
            icon: Icon(Platform.isAndroid ? Icons.save_alt : Icons.folder_open),
          )
        : OutlinedButton(
            onPressed: !exists ? null : () => runFileAction(context, () => saveOrRevealFile(selected.file)),
            child: Text(Platform.isAndroid ? '保存到文件' : '在文件夹中显示'),
          );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(child: share),
            const SizedBox(width: 8),
            Expanded(child: export),
            reveal,
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
          const SizedBox(height: 8),
          export,
          const SizedBox(height: 8),
          reveal,
        ],
      ),
    );
  }
}
