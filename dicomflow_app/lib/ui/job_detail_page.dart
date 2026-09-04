import 'dart:io';

import 'package:flutter/material.dart';
import '../domain/job.dart';
import '../engine/pipeline.dart';
import '../history/jobs_controller.dart';
import 'theme.dart';
import 'viewer/series_previewer.dart';
import 'widgets/preview_file_switcher.dart';
import 'widgets/result_action_bar.dart';
import 'widgets/workspace.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.job, required this.jobs});

  final JobRecord job;
  final JobsController jobs;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  late JobRecord _job;
  SeriesArtifact? _selected;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _selected = _firstPlayable(_job);
  }

  SeriesArtifact? _firstPlayable(JobRecord job) {
    final playable = job.outputs.where((o) => o.kind != 'zip');
    final src = playable.isNotEmpty ? playable.first : (job.outputs.isEmpty ? null : job.outputs.first);
    if (src == null) return null;
    return _toArtifact(src);
  }

  SeriesArtifact _toArtifact(JobOutput o) {
    return SeriesArtifact(
      file: File(o.path),
      frameCount: o.frameCount <= 0 ? 1 : o.frameCount,
      fps: o.fps,
      width: o.width > 0 ? o.width : 1,
      height: o.height > 0 ? o.height : 1,
      kind: o.kind,
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('会同时删除本机上的转换结果文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.jobs.delete(_job);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final failed = _job.status != 'SUCCEEDED';
    return Scaffold(
      appBar: AppBar(
        title: Text(_job.displayTitle),
        actions: [
          IconButton(
            tooltip: '删除',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _job.errorMessage ?? '转换失败',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
          : _selected == null
              ? const Center(child: Text('没有可预览的文件'))
              : _DetailBody(
                  job: _job,
                  selected: _selected!,
                  desktop: AppLayout.isDesktopShell(context),
                  onSelect: (out) => setState(() => _selected = _toArtifact(out)),
                ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.job,
    required this.selected,
    required this.desktop,
    required this.onSelect,
  });

  final JobRecord job;
  final SeriesArtifact selected;
  final bool desktop;
  final ValueChanged<JobOutput> onSelect;

  @override
  Widget build(BuildContext context) {
    final preview = SeriesPreviewer(
      key: ValueKey(selected.file.path),
      artifact: selected,
    );
    final actions = ResultActionBar(
      selected: selected,
      allFiles: [for (final o in job.outputs) File(o.path)],
      sourceFilename: job.sourceFilename,
      compact: !desktop,
    );
    if (desktop) {
      return Row(
        children: [
          Expanded(child: preview),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                actions,
                const Divider(height: 1),
                Expanded(
                  child: _FilePane(
                    outputs: job.outputs,
                    selectedPath: selected.file.path,
                    onSelect: onSelect,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: preview),
        actions,
        if (job.outputs.length > 1)
          PreviewFileSwitcher(
            items: [
              for (final o in job.outputs)
                PreviewFileItem(
                  id: o.path,
                  title: o.name.trim().isNotEmpty ? o.name : File(o.path).uri.pathSegments.last,
                  subtitle: o.kind == 'zip' ? '打包全部序列' : '${o.frameCount} 片 · ${o.fps} fps',
                  icon: o.kind == 'zip' ? Icons.folder_zip_outlined : Icons.movie_outlined,
                ),
            ],
            selectedId: selected.file.path,
            onSelected: (id) {
              for (final o in job.outputs) {
                if (o.path == id) {
                  onSelect(o);
                  break;
                }
              }
            },
          ),
      ],
    );
  }
}

class _FilePane extends StatelessWidget {
  const _FilePane({
    required this.outputs,
    required this.selectedPath,
    required this.onSelect,
  });

  final List<JobOutput> outputs;
  final String selectedPath;
  final ValueChanged<JobOutput> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            '文件 · ${outputs.length}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: outputs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final out = outputs[index];
              final on = out.path == selectedPath;
              return WorkspaceCard(
                selected: on,
                onTap: () => onSelect(out),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      out.kind == 'zip' ? Icons.folder_zip_outlined : Icons.movie_outlined,
                      color: on ? Theme.of(context).colorScheme.primary : tokens.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            out.name.trim().isNotEmpty ? out.name : File(out.path).uri.pathSegments.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            out.kind == 'zip' ? '打包全部序列' : '${out.frameCount} 片 · ${out.fps} fps',
                            style: TextStyle(color: tokens.muted2, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
