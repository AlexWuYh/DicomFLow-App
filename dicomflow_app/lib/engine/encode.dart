import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/errors.dart';
import 'window.dart';

Future<ProcessResult> runProcessTimed(
  String executable,
  List<String> arguments, {
  Duration timeout = const Duration(minutes: 15),
}) async {
  final process = await Process.start(executable, arguments);
  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  process.stdout.transform(utf8.decoder).listen(stdoutBuf.write);
  process.stderr.transform(utf8.decoder).listen(stderrBuf.write);
  final timer = Timer(timeout, () {
    process.kill(ProcessSignal.sigkill);
  });
  try {
    final code = await process.exitCode;
    return ProcessResult(process.pid, code, stdoutBuf.toString(), stderrBuf.toString());
  } finally {
    timer.cancel();
  }
}

List<String> ffmpegCandidates() {
  final out = <String>[];
  final env = Platform.environment['DICOMFLOW_FFMPEG'];
  if (env != null && env.isNotEmpty) out.add(env);
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    out.addAll([
      p.join(exeDir, 'ffmpeg'),
      p.join(exeDir, 'ffmpeg.exe'),
      p.normalize(p.join(exeDir, '..', 'Resources', 'ffmpeg')),
      p.normalize(p.join(exeDir, '..', 'Resources', 'ffmpeg.exe')),
    ]);
  } catch (_) {}
  out.addAll(const [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
  ]);
  return out;
}

String? peekFfmpeg() {
  for (final c in ffmpegCandidates()) {
    try {
      if (c.contains(p.separator) && !File(c).existsSync()) continue;
      if (Process.runSync(c, ['-version']).exitCode == 0) return c;
    } catch (_) {}
  }
  return null;
}

Future<String> resolveFfmpeg({String? override}) async {
  if (override != null && override.isNotEmpty) {
    return override;
  }
  for (final c in ffmpegCandidates()) {
    try {
      if (c.contains(p.separator) && !File(c).existsSync()) continue;
      final result = await Process.run(c, ['-version']);
      if (result.exitCode == 0) return c;
    } catch (_) {
      // try next
    }
  }
  throw const EngineException(
    EngineException.convertError,
    '未找到 ffmpeg，无法编码。请把 ffmpeg 放到应用目录，或设置环境变量 DICOMFLOW_FFMPEG。',
  );
}

typedef FfmpegProcess = Future<ProcessResult> Function(
  List<String> args, {
  String? ffmpegPath,
});

/// Desktop default: bundled/PATH CLI. Android sets this to FFmpegKit on the UI isolate.
FfmpegProcess ffmpegProcess = ffmpegProcessCli;

Future<ProcessResult> ffmpegProcessCli(
  List<String> args, {
  String? ffmpegPath,
}) async {
  final ffmpeg = await resolveFfmpeg(override: ffmpegPath);
  return runProcessTimed(ffmpeg, args);
}

Future<ProcessResult> runFfmpeg(
  List<String> args, {
  String? ffmpegPath,
}) {
  return ffmpegProcess(args, ffmpegPath: ffmpegPath);
}

Future<File> writeMp4({
  required List<WindowResult> frames,
  required File output,
  required int fps,
  required int crf,
  String? ffmpegPath,
}) async {
  if (frames.isEmpty) {
    throw const EngineException(EngineException.convertError, '没有可编码的帧');
  }
  final width = frames.first.width;
  final height = frames.first.height;
  for (final f in frames) {
    if (f.width != width || f.height != height) {
      throw const EngineException(
        EngineException.convertError,
        '序列内分辨率不一致',
      );
    }
  }

  output.parent.createSync(recursive: true);
  final raw = File('${output.path}.rgb');
  final sink = raw.openWrite();
  for (final frame in frames) {
    sink.add(frame.rgb);
  }
  await sink.close();
  try {
    final result = await runFfmpeg([
      '-y',
      '-nostdin',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgb24',
      '-s',
      '${width}x$height',
      '-r',
      '$fps',
      '-i',
      raw.path,
      '-an',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-crf',
      '$crf',
      '-preset',
      'medium',
      output.path,
    ], ffmpegPath: ffmpegPath);
    if (result.exitCode != 0 || !output.existsSync() || output.lengthSync() == 0) {
      throw EngineException(
        EngineException.convertError,
        'MP4 编码失败',
        detail: result.stderr.toString().trim(),
      );
    }
  } finally {
    if (raw.existsSync()) raw.deleteSync();
  }
  return output;
}

Future<File> writeGif({
  required List<WindowResult> frames,
  required File output,
  required int fps,
  required int maxColors,
  String? ffmpegPath,
}) async {
  if (frames.isEmpty) {
    throw const EngineException(EngineException.convertError, 'GIF 无有效帧');
  }
  if (maxColors < 2) {
    throw const EngineException(EngineException.convertError, 'GIF 调色板过小');
  }
  final width = frames.first.width;
  final height = frames.first.height;
  for (final f in frames) {
    if (f.width != width || f.height != height) {
      throw const EngineException(
        EngineException.convertError,
        '序列内分辨率不一致',
      );
    }
  }
  output.parent.createSync(recursive: true);
  final raw = File('${output.path}.rgb');
  final sink = raw.openWrite();
  for (final frame in frames) {
    sink.add(frame.rgb);
  }
  await sink.close();
  try {
    final palette = File('${output.path}.palette.png');
    final result = await runFfmpeg([
      '-y',
      '-nostdin',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgb24',
      '-s',
      '${width}x$height',
      '-r',
      '$fps',
      '-i',
      raw.path,
      '-vf',
      'palettegen=max_colors=$maxColors:stats_mode=full',
      palette.path,
    ]);
    if (result.exitCode != 0 || !palette.existsSync()) {
      final fallback = await runFfmpeg([
        '-y',
        '-nostdin',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        '-s',
        '${width}x$height',
        '-r',
        '$fps',
        '-i',
        raw.path,
        '-an',
        '-c:v',
        'gif',
        output.path,
      ]);
      if (fallback.exitCode != 0 || !output.existsSync() || output.lengthSync() == 0) {
        throw EngineException(
          EngineException.convertError,
          'GIF 编码失败',
          detail: fallback.stderr.toString().trim(),
        );
      }
    } else {
      final mapped = await runFfmpeg([
        '-y',
        '-nostdin',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        '-s',
        '${width}x$height',
        '-r',
        '$fps',
        '-i',
        raw.path,
        '-i',
        palette.path,
        '-lavfi',
        'paletteuse=dither=bayer',
        '-an',
        output.path,
      ]);
      if (mapped.exitCode != 0 || !output.existsSync() || output.lengthSync() == 0) {
        throw EngineException(
          EngineException.convertError,
          'GIF 编码失败',
          detail: mapped.stderr.toString().trim(),
        );
      }
    }
  } finally {
    if (raw.existsSync()) raw.deleteSync();
    final palette = File('${output.path}.palette.png');
    if (palette.existsSync()) palette.deleteSync();
  }
  return output;
}

int probeFrameCount(File mp4, {String? ffprobePath}) {
  final bin = ffprobePath ??
      (File('/opt/homebrew/bin/ffprobe').existsSync()
          ? '/opt/homebrew/bin/ffprobe'
          : 'ffprobe');
  final result = Process.runSync(bin, [
    '-v',
    'error',
    '-count_frames',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=nb_read_frames',
    '-of',
    'default=nokey=1:noprint_wrappers=1',
    mp4.path,
  ]);
  if (result.exitCode != 0) {
    throw EngineException(
      EngineException.convertError,
      'ffprobe 失败',
      detail: result.stderr.toString(),
    );
  }
  return int.parse((result.stdout as String).trim());
}
