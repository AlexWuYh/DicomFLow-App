import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../domain/convert_params.dart';
import '../domain/errors.dart';
import '../domain/job.dart';
import '../domain/progress.dart';
import '../engine/archive.dart';
import '../engine/convert_worker.dart';
import '../engine/encode.dart';
import '../engine/ffmpeg_kit_runner.dart';
import '../engine/pipeline.dart';
import '../engine/sevenzip_kit_runner.dart';
import '../history/jobs_controller.dart';
import '../history/paths.dart';
import 'theme.dart';
import 'viewer/series_previewer.dart';
import 'widgets/brand_mark.dart';
import 'widgets/convert_steps.dart';
import 'widgets/result_action_bar.dart';
import 'widgets/workspace.dart';

/// Convert workspace: pick or drop an archive, set options, preview, share.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onToggleTheme, required this.jobs});

  final VoidCallback onToggleTheme;
  final JobsController jobs;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _zip;
  bool _busy = false;
  var _dragging = false;
  ProgressEvent _proc = const ProgressEvent(phase: 'PENDING', percent: 0, message: '');
  ConvertResult? _result;
  SeriesArtifact? _selected;
  String? _error;
  var _format = OutputFormat.mp4;
  var _quality = Quality.high;
  var _fps = 10;
  var _merge = false;

  static const _archiveExt = {'.zip', '.rar', '.7z'};

  void _deleteFailedOutput(Directory? dir) {
    if (dir == null || !dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  Future<void> _persistJob(JobRecord job) async {
    try {
      await widget.jobs.upsert(job);
    } catch (_) {}
  }

  void _acceptPath(String path) {
    final ext = p.extension(path).toLowerCase();
    if (!_archiveExt.contains(ext)) {
      setState(() => _error = '请选择 zip / rar / 7z 压缩包');
      return;
    }
    setState(() {
      _zip = File(path);
      _result = null;
      _selected = null;
      _error = null;
      _proc = const ProgressEvent(phase: 'PENDING', percent: 0, message: '');
    });
  }

  Future<void> _pickZip() async {
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: '打开 DICOM 压缩包',
        type: FileType.custom,
        allowedExtensions: const ['zip', 'rar', '7z'],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法打开文件选择器');
      return;
    }
    if (picked == null) return;
    final path = picked.path;
    if (path == null) {
      if (!mounted) return;
      setState(() => _error = '无法读取所选文件，请重新选择 zip / rar / 7z');
      return;
    }
    _acceptPath(path);
  }

  void _resetForNewConvert() {
    setState(() {
      _zip = null;
      _result = null;
      _selected = null;
      _error = null;
      _busy = false;
      _dragging = false;
      _proc = const ProgressEvent(phase: 'PENDING', percent: 0, message: '');
    });
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    if (_busy || details.files.isEmpty) return;
    final item = details.files.first;
    final bookmark = item.extraAppleBookmark;
    if (bookmark != null && bookmark.isNotEmpty) {
      try {
        await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
      } catch (_) {}
    }
    _acceptPath(item.path);
  }

  Future<void> _convert() async {
    final zip = _zip;
    if (zip == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _selected = null;
      _proc = const ProgressEvent(phase: 'EXTRACTING', percent: 1, message: '开始转换…');
    });
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final created = DateTime.now();
    Directory? outDir;
    try {
      outDir = await jobOutputDir('$stamp');
      final params = ConvertParams(
        format: _format,
        quality: _quality,
        fps: _fps,
        merge: _merge,
      );
      void onProgress(ProgressEvent event) {
        if (!mounted) return;
        setState(() => _proc = event);
      }

      final ConvertResult result;
      if (Platform.isAndroid) {
        ffmpegProcess = ffmpegProcessKit;
        bundledArchiveExtract = extractWithAndroidSevenZip;
        result = await convertDicomPackage(
          input: zip,
          outputDir: outDir,
          params: params,
          onProgress: onProgress,
        );
      } else {
        result = await convertDicomPackageInBackground(
          input: zip,
          outputDir: outDir,
          params: params,
          onProgress: onProgress,
        );
      }
      await _persistJob(
        JobRecord(
          id: '$stamp',
          createdAt: created,
          completedAt: DateTime.now(),
          status: 'SUCCEEDED',
          sourceFilename: p.basename(zip.path),
          format: _format.name,
          quality: _quality.name,
          fps: result.fps,
          merge: _merge,
          outputs: [
            for (final s in result.series)
              JobOutput(
                name: p.basename(s.file.path),
                path: s.file.path,
                sizeBytes: s.file.existsSync() ? s.file.lengthSync() : 0,
                frameCount: s.frameCount,
                fps: s.fps,
                width: s.width,
                height: s.height,
                kind: s.kind,
              ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected = result.series.firstWhere(
          (s) => !s.isZip,
          orElse: () => result.series.first,
        );
        _busy = false;
      });
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {}
    } on EngineException catch (e) {
      _deleteFailedOutput(outDir);
      await _persistJob(
        JobRecord(
          id: '$stamp',
          createdAt: created,
          completedAt: DateTime.now(),
          status: 'FAILED',
          sourceFilename: p.basename(zip.path),
          errorCode: e.code,
          errorMessage: e.message,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = (e.detail == null || e.detail!.isEmpty) ? e.message : '${e.message}\n${e.detail}';
        _proc = ProgressEvent(phase: 'FAILED', percent: 0, message: '${e.code}: ${e.message}');
      });
    } catch (e) {
      _deleteFailedOutput(outDir);
      await _persistJob(
        JobRecord(
          id: '$stamp',
          createdAt: created,
          completedAt: DateTime.now(),
          status: 'FAILED',
          sourceFilename: p.basename(zip.path),
          errorCode: EngineException.convertError,
          errorMessage: e.toString(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _proc = ProgressEvent(phase: 'FAILED', percent: 0, message: e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desktop = AppLayout.isDesktopShell(context);
    final body = DropTarget(
      enable: !_busy && (Platform.isMacOS || Platform.isWindows || Platform.isLinux),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) {
        setState(() => _dragging = false);
        _onDrop(d);
      },
      child: ColoredBox(
        color: _dragging
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: _result != null && _selected != null
            ? _ResultWorkspace(
                result: _result!,
                selected: _selected!,
                desktop: desktop,
                sourceFilename: _zip == null ? 'dicomflow' : p.basename(_zip!.path),
                onSelect: (item) => setState(() => _selected = item),
                onNew: _busy ? null : _resetForNewConvert,
              )
            : _SetupWorkspace(
                fileName: _zip == null ? null : p.basename(_zip!.path),
                busy: _busy,
                dragging: _dragging,
                desktop: desktop,
                progress: _proc,
                error: _error,
                format: _format,
                quality: _quality,
                fps: _fps,
                merge: _merge,
                onPick: _busy ? null : _pickZip,
                onConvert: _zip == null || _busy ? null : _convert,
                onFormat: _busy ? null : (v) => setState(() => _format = v),
                onQuality: _busy
                    ? null
                    : (v) => setState(() {
                          _quality = v;
                          final cap = profileFor(v).fpsCap;
                          if (cap != null && _fps > cap) _fps = cap;
                        }),
                onFps: _busy ? null : (v) => setState(() => _fps = v),
                onMerge: _busy ? null : (v) => setState(() => _merge = v),
              ),
      ),
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        title: desktop
            ? Text(
                _result != null ? '转换结果' : '转换',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              )
            : const Row(
                children: [
                  BrandMark(size: 28),
                  SizedBox(width: 10),
                  Text('DicomFlow'),
                ],
              ),
        actions: [
          if (_result != null)
            IconButton(
              tooltip: '回到首页',
              onPressed: _busy ? null : _resetForNewConvert,
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: isDark ? '切换到浅色主题' : '切换到深色主题',
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: body,
    );

    final nativeMenu = PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.about);
    if (!nativeMenu) return scaffold;
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'DicomFlow',
          menus: const [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: '文件',
          menus: [
            PlatformMenuItem(
              label: '打开压缩包…',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: !Platform.isWindows,
                control: Platform.isWindows,
              ),
              onSelected: _busy ? null : _pickZip,
            ),
          ],
        ),
      ],
      child: scaffold,
    );
  }
}

class _SetupWorkspace extends StatelessWidget {
  const _SetupWorkspace({
    required this.fileName,
    required this.busy,
    required this.dragging,
    required this.desktop,
    required this.progress,
    required this.error,
    required this.format,
    required this.quality,
    required this.fps,
    required this.merge,
    required this.onPick,
    required this.onConvert,
    required this.onFormat,
    required this.onQuality,
    required this.onFps,
    required this.onMerge,
  });

  final String? fileName;
  final bool busy;
  final bool dragging;
  final bool desktop;
  final ProgressEvent progress;
  final String? error;
  final OutputFormat format;
  final Quality quality;
  final int fps;
  final bool merge;
  final VoidCallback? onPick;
  final VoidCallback? onConvert;
  final ValueChanged<OutputFormat>? onFormat;
  final ValueChanged<Quality>? onQuality;
  final ValueChanged<int>? onFps;
  final ValueChanged<bool>? onMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final fpsItems = [
      for (final n in const [5, 8, 10, 12, 15, 24, 30])
        if (profileFor(quality).fpsCap == null || n <= profileFor(quality).fpsCap!) n,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            AppColors.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.04),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, AppLayout.listBottomInset(context)),
            children: [
              if (fileName == null) ...[
                DashedDropFrame(
                  highlighted: dragging,
                  child: Column(
                    children: [
                      IconWell(
                        icon: dragging ? Icons.file_download : Icons.folder_zip_outlined,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        dragging ? '松开即可打开' : '打开医院给的压缩包',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desktop
                            ? '把 zip / rar / 7z 拖进窗口，或点选文件。转换只在本机完成。'
                            : '选择医院导出的 zip / rar / 7z。转换只在本机完成，不必上网。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FormatChip(label: 'ZIP'),
                          FormatChip(label: 'RAR'),
                          FormatChip(label: '7Z'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: onPick,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('选择压缩包'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const ConvertStepsGuide(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onConvert,
                    child: const Text('开始转换'),
                  ),
                ),
              ] else ...[
                WorkspaceCard(
                  onTap: onPick,
                  child: Row(
                    children: [
                      const IconWell(icon: Icons.folder_zip_outlined, size: 48, iconSize: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName!,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('点击可更换文件', style: TextStyle(color: tokens.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: onPick, child: const Text('更换')),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '输出格式',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FormatTile(
                        selected: format == OutputFormat.mp4,
                        icon: Icons.movie_outlined,
                        title: 'MP4',
                        caption: '适合发给医生播放',
                        onTap: onFormat == null ? null : () => onFormat!(OutputFormat.mp4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormatTile(
                        selected: format == OutputFormat.gif,
                        icon: Icons.gif_box_outlined,
                        title: 'GIF',
                        caption: '适合插进文档或聊天',
                        onTap: onFormat == null ? null : () => onFormat!(OutputFormat.gif),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                WorkspaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('清晰度', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const [
                            (Quality.high, '高清'),
                            (Quality.medium, '标准'),
                            (Quality.low, '流畅'),
                          ])
                            ChoiceChip(
                              label: Text(item.$2),
                              selected: quality == item.$1,
                              onSelected: onQuality == null
                                  ? null
                                  : (v) {
                                      if (v) onQuality!(item.$1);
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('帧率', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final n in fpsItems)
                            ChoiceChip(
                              label: Text('$n fps'),
                              selected: fps == n,
                              onSelected: onFps == null
                                  ? null
                                  : (v) {
                                      if (v) onFps!(n);
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WorkspaceCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('合并成一个文件'),
                    subtitle: Text(
                      '多段影像拼成一条，方便一次发送',
                      style: TextStyle(color: tokens.muted2),
                    ),
                    value: merge,
                    onChanged: onMerge,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onConvert,
                    child: Text(busy ? '转换中…' : '开始转换'),
                  ),
                ),
                if (busy) ...[
                  const SizedBox(height: 16),
                  WorkspaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.message.isEmpty ? '正在转换…' : progress.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: (progress.percent / 100).clamp(0, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  WorkspaceCard(
                    accent: Theme.of(context).colorScheme.error,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 28),
              Text(
                '便于沟通查阅，不作诊断依据',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return WorkspaceCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: selected ? scheme.primary : tokens.muted),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: tokens.muted, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _ResultWorkspace extends StatelessWidget {
  const _ResultWorkspace({
    required this.result,
    required this.selected,
    required this.desktop,
    required this.sourceFilename,
    required this.onSelect,
    required this.onNew,
  });

  final ConvertResult result;
  final SeriesArtifact selected;
  final bool desktop;
  final String sourceFilename;
  final ValueChanged<SeriesArtifact> onSelect;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final files = [for (final s in result.series) s.file];
    final preview = SeriesPreviewer(
      key: ValueKey(selected.file.path),
      artifact: selected,
    );
    final actions = ResultActionBar(
      selected: selected,
      allFiles: files,
      sourceFilename: sourceFilename,
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
                _ResultHeader(onNew: onNew),
                actions,
                const Divider(height: 1),
                Expanded(
                  child: _SeriesFileList(
                    result: result,
                    selected: selected,
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
        _ResultHeader(onNew: onNew),
        SizedBox(
          height: 96,
          child: _SeriesFileList(
            result: result,
            selected: selected,
            onSelect: onSelect,
            horizontal: true,
          ),
        ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.onNew});

  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('再转一个'),
        ),
      ),
    );
  }
}

class _SeriesFileList extends StatelessWidget {
  const _SeriesFileList({
    required this.result,
    required this.selected,
    required this.onSelect,
    this.horizontal = false,
  });

  final ConvertResult result;
  final SeriesArtifact selected;
  final ValueChanged<SeriesArtifact> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        itemCount: result.series.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = result.series[index];
          final on = item.file.path == selected.file.path;
          return SizedBox(
            width: 200,
            child: WorkspaceCard(
              selected: on,
              onTap: () => onSelect(item),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.basename(item.file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    item.isZip ? '打包全部序列' : '${item.frameCount} 片 · ${item.fps} fps',
                    style: TextStyle(color: tokens.muted2, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: result.series.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = result.series[index];
        return WorkspaceCard(
          selected: item.file.path == selected.file.path,
          onTap: () => onSelect(item),
          child: Row(
            children: [
              Icon(
                item.isZip ? Icons.folder_zip_outlined : Icons.movie_outlined,
                color: item.file.path == selected.file.path
                    ? Theme.of(context).colorScheme.primary
                    : tokens.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(item.file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      item.isZip ? '打包全部序列' : '${item.frameCount} 片 · ${item.fps} fps',
                      style: TextStyle(color: tokens.muted2, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
