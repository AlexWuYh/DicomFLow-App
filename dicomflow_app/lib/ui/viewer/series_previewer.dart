import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/slice_index.dart';
import '../../engine/pipeline.dart';
import 'gif_preview.dart';
import 'slice_scrub_bar.dart';
import 'zoomable_stage.dart';

const _gifCacheLimit = 2;
final Map<String, GifPreviewFrames> _gifPreviewCache = {};

class SeriesPreviewer extends StatefulWidget {
  const SeriesPreviewer({super.key, required this.artifact});

  final SeriesArtifact artifact;

  @override
  State<SeriesPreviewer> createState() => _SeriesPreviewerState();
}

class _SeriesPreviewerState extends State<SeriesPreviewer> {
  VideoPlayerController? _controller;
  final _zoomKey = GlobalKey<ZoomableStageState>();
  var _ready = false;
  var _failed = false;
  var _playing = false;
  var _slice = 1;
  var _openGen = 0;
  var _gifNative = false;
  List<Uint8List> _gifFrames = const [];
  Timer? _gifTimer;

  SeriesArtifact get _art => widget.artifact;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant SeriesPreviewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artifact.file.path != widget.artifact.file.path) {
      _open();
    }
  }

  Future<void> _open() async {
    final gen = ++_openGen;
    _gifTimer?.cancel();
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_onTick);
      unawaited(previous.dispose());
    }
    if (!mounted || gen != _openGen) return;
    setState(() {
      _ready = false;
      _failed = false;
      _playing = false;
      _slice = 1;
      _gifNative = false;
      _gifFrames = const [];
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted || gen != _openGen) return;
    final file = _art.file;
    if (!file.existsSync() || _art.isZip) {
      return;
    }
    if (_art.isGif) {
      await _openGif(file, gen);
      return;
    }
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (!mounted || gen != _openGen) return;
      setState(() => _failed = true);
      return;
    }
    if (!mounted || gen != _openGen) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    _controller = controller;
    setState(() {
      _ready = controller.value.isInitialized;
      _slice = 1;
    });
  }

  Future<void> _openGif(File file, int gen) async {
    final cached = _gifPreviewCache[file.path];
    if (cached != null) {
      if (!mounted || gen != _openGen) return;
      setState(() {
        _gifFrames = cached.frames;
        _ready = true;
        _slice = 1;
      });
      return;
    }
    try {
      final decoded = await loadGifPreview(file.path);
      if (decoded.frames.isEmpty) {
        throw StateError('GIF 没有帧');
      }
      _rememberGif(file.path, decoded);
      if (!mounted || gen != _openGen) return;
      setState(() {
        _gifFrames = decoded.frames;
        _gifNative = false;
        _ready = true;
        _slice = 1;
      });
    } catch (_) {
      if (!mounted || gen != _openGen) return;
      setState(() {
        _gifNative = true;
        _ready = true;
        _failed = false;
        _slice = 1;
      });
    }
  }

  void _rememberGif(String path, GifPreviewFrames data) {
    _gifPreviewCache.remove(path);
    _gifPreviewCache[path] = data;
    while (_gifPreviewCache.length > _gifCacheLimit) {
      _gifPreviewCache.remove(_gifPreviewCache.keys.first);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final playing = c.value.isPlaying;
    final slice = sliceFromPosition(
      position: c.value.position,
      fps: _art.fps,
      total: _art.frameCount,
    );
    if (playing != _playing || slice != _slice) {
      setState(() {
        _playing = playing;
        _slice = slice;
      });
    }
  }

  Future<void> _seekSlice(int slice) async {
    final c = _controller;
    if (c != null) {
      await c.pause();
      await c.seekTo(positionForSlice(slice: slice, fps: _art.fps));
    }
    _gifTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _slice = slice;
      _playing = false;
    });
  }

  Future<void> _step(int delta) async {
    final total = _gifFrames.isNotEmpty ? _gifFrames.length : _art.frameCount;
    final next = (_slice + delta).clamp(1, total <= 0 ? 1 : total);
    await _seekSlice(next);
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c != null) {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
      return;
    }
    if (_gifFrames.isEmpty) return;
    if (_playing) {
      _gifTimer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    final interval = Duration(milliseconds: (1000 / (_art.fps <= 0 ? 10 : _art.fps)).round());
    _gifTimer = Timer.periodic(interval, (_) {
      if (!mounted || _gifFrames.isEmpty) return;
      setState(() {
        _slice = _slice >= _gifFrames.length ? 1 : _slice + 1;
      });
    });
  }

  @override
  void dispose() {
    _gifTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_art.isZip) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_zip_outlined, size: 48),
              SizedBox(height: 8),
              Text('打包文件，请分享或在文件夹中打开'),
            ],
          ),
        ),
      );
    }
    if (_art.isGif) {
      return _buildPlayer(gif: true);
    }
    return _buildPlayer(gif: false);
  }

  Widget _buildPlayer({required bool gif}) {
    final total = gif
        ? (_gifFrames.isEmpty ? _art.frameCount : _gifFrames.length)
        : _art.frameCount;
    final c = _controller;
    final ratio = gif
        ? (_art.width > 0 && _art.height > 0 ? _art.width / _art.height : 1.0)
        : (_ready && c != null && c.value.aspectRatio > 0
            ? c.value.aspectRatio
            : (_art.width / _art.height.clamp(1, 1 << 20)));
    final stage = ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: _stageChild(gif: gif),
        ),
      ),
    );
    final controls = SliceScrubBar(
      current: gif ? _slice.clamp(1, total <= 0 ? 1 : total) : _slice,
      total: gif ? (total <= 0 ? 1 : total) : _art.frameCount,
      playing: _playing,
      onChanged: _seekSlice,
      onPlayPause: _togglePlay,
      onStep: _step,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        if (bounded) {
          return Column(
            children: [
              Expanded(child: stage),
              controls,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: ratio, child: stage),
            controls,
          ],
        );
      },
    );
  }

  Widget _stageChild({required bool gif}) {
    if (!_art.file.existsSync()) {
      return const Center(child: Text('文件已删除', style: TextStyle(color: Colors.white70)));
    }
    if (_failed) {
      return const Center(child: Text('无法播放', style: TextStyle(color: Colors.white70)));
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final media = gif
        ? (_gifNative || _gifFrames.isEmpty
            ? Image.file(_art.file, fit: BoxFit.contain, gaplessPlayback: true)
            : Image.memory(
                _gifFrames[(_slice - 1).clamp(0, _gifFrames.length - 1)],
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ))
        : VideoPlayer(_controller!);
    return Stack(
      fit: StackFit.expand,
      children: [
        ZoomableStage(key: _zoomKey, child: media),
        if (!_playing)
          Center(
            child: Material(
              color: const Color(0x99000000),
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('preview-play'),
                tooltip: '播放',
                iconSize: 52,
                color: Colors.white,
                onPressed: _togglePlay,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ),
          ),
        Positioned(
          right: 8,
          top: 8,
          child: Column(
            children: [
              _ZoomChip(
                key: const Key('zoom-in'),
                tooltip: '放大',
                icon: Icons.add,
                onPressed: () => _zoomKey.currentState?.zoomIn(),
              ),
              const SizedBox(height: 6),
              _ZoomChip(
                key: const Key('zoom-out'),
                tooltip: '缩小',
                icon: Icons.remove,
                onPressed: () => _zoomKey.currentState?.zoomOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC111827),
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: Colors.white,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
