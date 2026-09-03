import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../domain/convert_params.dart';
import '../domain/errors.dart';
import '../domain/progress.dart';
import 'archive.dart';
import 'discover.dart';
import 'encode.dart';
import 'pixels.dart';
import 'window.dart';

class SeriesArtifact {
  const SeriesArtifact({
    required this.file,
    required this.frameCount,
    required this.fps,
    required this.width,
    required this.height,
    this.kind = 'series',
  });

  final File file;
  final int frameCount;
  final int fps;
  final int width;
  final int height;
  final String kind;

  bool get isGif => file.path.toLowerCase().endsWith('.gif');
  bool get isZip => kind == 'zip' || file.path.toLowerCase().endsWith('.zip');
}

class ConvertResult {
  const ConvertResult({
    required this.series,
    required this.fps,
  });

  final List<SeriesArtifact> series;
  final int fps;

  List<File> get seriesOutputs => [for (final s in series) s.file];
  List<File> get outputFiles => seriesOutputs;
}

const blackSeconds = 0.4;

Future<ConvertResult> convertDicomPackage({
  required FileSystemEntity input,
  required Directory outputDir,
  ConvertParams params = const ConvertParams(),
  Directory? workDir,
  ProgressCallback? onProgress,
  String? ffmpegPath,
}) async {
  void emit(ProgressEvent e) => onProgress?.call(e);

  outputDir.createSync(recursive: true);
  final ownedWork = workDir == null;
  final extractDir = workDir ?? Directory(p.join(outputDir.path, '_work'));

  try {
    return await _convertBody(
      input: input,
      outputDir: outputDir,
      params: params,
      extractDir: extractDir,
      emit: emit,
      ffmpegPath: ffmpegPath,
    );
  } finally {
    if (ownedWork && extractDir.existsSync()) {
      try {
        extractDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

Future<ConvertResult> _convertBody({
  required FileSystemEntity input,
  required Directory outputDir,
  required ConvertParams params,
  required Directory extractDir,
  required void Function(ProgressEvent e) emit,
  String? ffmpegPath,
}) async {
  emit(const ProgressEvent(phase: 'EXTRACTING', percent: 5, message: '正在解压…'));
  final root = await prepareInput(input, destDir: extractDir);

  emit(const ProgressEvent(phase: 'DISCOVERING', percent: 20, message: '正在查找影像…'));
  final instances = findDicomInstances(root);
  final seriesList = groupSeries(instances);

  final profile = profileFor(params.quality);
  var fps = params.fps;
  if (profile.fpsCap != null && fps > profile.fpsCap!) {
    fps = profile.fpsCap!;
  }

  emit(
    ProgressEvent(
      phase: 'CONVERTING',
      percent: 30,
      message: '开始转换',
      seriesTotal: seriesList.length,
    ),
  );

  final used = <String>{};
  final artifacts = <SeriesArtifact>[];
  final preparedSeries = <List<WindowResult>>[];
  final skippedReasons = <String>[];
  for (var s = 0; s < seriesList.length; s++) {
    final series = seriesList[s];
    final frames = <WindowResult>[];
    for (final inst in series.instances) {
      try {
        frames.addAll(await framesForInstance(inst.path));
      } on EngineException catch (e) {
        skippedReasons.add(e.message);
      } catch (_) {
        skippedReasons.add('实例无法解码');
      }
    }
    if (frames.isEmpty) continue;
    final gif = params.format == OutputFormat.gif;
    var prepared = frames;
    final (tw, th) = scaledSize(
      width: frames.first.width,
      height: frames.first.height,
      scale: profile.scale,
      maxSide: gif ? profile.gifMaxSide : profile.maxSide,
    );
    if (tw != frames.first.width || th != frames.first.height) {
      prepared = [for (final f in frames) resizeRgb(f, tw, th)];
    }
    if (gif && prepared.length > profile.gifMaxFrames) {
      final stride = math.max(1, (prepared.length / profile.gifMaxFrames).ceil());
      prepared = [
        for (var i = 0; i < prepared.length; i += stride) prepared[i],
      ];
    }
    final stem = series.uniqueOutputStem(used);
    final ext = gif ? 'gif' : 'mp4';
    final out = File(p.join(outputDir.path, '$stem.$ext'));
    emit(
      ProgressEvent(
        phase: 'CONVERTING',
        percent: 30 + ((s / seriesList.length) * 60).round(),
        message: '正在编码 ${series.safeName}',
        seriesIndex: s + 1,
        seriesTotal: seriesList.length,
        frameTotal: frames.length,
      ),
    );
    if (gif) {
      await writeGif(
        frames: prepared,
        output: out,
        fps: fps,
        maxColors: profile.gifColors,
        ffmpegPath: ffmpegPath,
      );
    } else {
      await writeMp4(
        frames: prepared,
        output: out,
        fps: fps,
        crf: profile.mp4Crf,
        ffmpegPath: ffmpegPath,
      );
    }
    artifacts.add(
      SeriesArtifact(
        file: out,
        frameCount: prepared.length,
        fps: fps,
        width: prepared.first.width,
        height: prepared.first.height,
      ),
    );
    if (params.merge) {
      preparedSeries.add(prepared);
    }
  }

  if (artifacts.isEmpty) {
    final unique = <String>{...skippedReasons};
    throw EngineException(
      EngineException.convertError,
      unique.isEmpty ? '没有成功转换的序列' : unique.join('；'),
    );
  }

  emit(
    const ProgressEvent(phase: 'PACKAGING', percent: 95, message: '整理输出…'),
  );
  File? bundle;
  if (params.merge && preparedSeries.length > 1) {
    emit(const ProgressEvent(phase: 'PACKAGING', percent: 92, message: '合并序列…'));
    var tw = 0;
    var th = 0;
    for (final frames in preparedSeries) {
      tw = math.max(tw, frames.first.width);
      th = math.max(th, frames.first.height);
    }
    if (tw % 2 != 0) tw += 1;
    if (th % 2 != 0) th += 1;
    final blackCount = math.max(1, (blackSeconds * fps).round());
    final mergedFrames = <WindowResult>[];
    for (var i = 0; i < preparedSeries.length; i++) {
      for (final frame in preparedSeries[i]) {
        mergedFrames.add(fitPad(frame, tw, th));
      }
      if (i < preparedSeries.length - 1) {
        final black = blackFrame(tw, th);
        for (var b = 0; b < blackCount; b++) {
          mergedFrames.add(black);
        }
      }
    }
    final gif = params.format == OutputFormat.gif;
    if (gif && mergedFrames.length > profile.gifMaxFrames) {
      final src = List<WindowResult>.from(mergedFrames);
      final stride = math.max(1, (src.length / profile.gifMaxFrames).ceil());
      mergedFrames
        ..clear()
        ..addAll([for (var i = 0; i < src.length; i += stride) src[i]]);
    }
    final mergedFile = File(p.join(outputDir.path, gif ? 'merged.gif' : 'merged.mp4'));
    if (gif) {
      await writeGif(
        frames: mergedFrames,
        output: mergedFile,
        fps: fps,
        maxColors: profile.gifColors,
        ffmpegPath: ffmpegPath,
      );
    } else {
      await writeMp4(
        frames: mergedFrames,
        output: mergedFile,
        fps: fps,
        crf: profile.mp4Crf,
        ffmpegPath: ffmpegPath,
      );
    }
    artifacts.insert(
      0,
      SeriesArtifact(
        file: mergedFile,
        frameCount: mergedFrames.length,
        fps: fps,
        width: tw,
        height: th,
        kind: 'merged',
      ),
    );
  } else if (artifacts.length > 1) {
    final zipPath = File(p.join(outputDir.path, 'result.zip'));
    final archive = Archive();
    for (final item in artifacts) {
      archive.add(
        ArchiveFile.bytes(p.basename(item.file.path), item.file.readAsBytesSync()),
      );
    }
    zipPath.writeAsBytesSync(ZipEncoder().encodeBytes(archive), flush: true);
    bundle = zipPath;
    artifacts.add(
      SeriesArtifact(
        file: zipPath,
        frameCount: 0,
        fps: fps,
        width: 0,
        height: 0,
        kind: 'zip',
      ),
    );
  }
  emit(
    ProgressEvent(
      phase: 'SUCCEEDED',
      percent: 100,
      message: bundle == null ? '完成，共 ${artifacts.length} 个文件' : '完成，已打包 result.zip',
    ),
  );
  return ConvertResult(series: artifacts, fps: fps);
}
