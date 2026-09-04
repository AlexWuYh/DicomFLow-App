import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../domain/convert_params.dart';
import '../domain/errors.dart';
import '../domain/progress.dart';
import 'pipeline.dart';

/// Run [convertDicomPackage] off the UI isolate. Progress events are sent back.
Future<ConvertResult> convertDicomPackageInBackground({
  required File input,
  required Directory outputDir,
  ConvertParams params = const ConvertParams(),
  ProgressCallback? onProgress,
  String? ffmpegPath,
}) async {
  final receive = ReceivePort();
  final isolate = await Isolate.spawn<SendPort>(
    convertIsolateMain,
    receive.sendPort,
    errorsAreFatal: false,
  );
  final ready = Completer<SendPort>();
  final done = Completer<ConvertResult>();
  late final StreamSubscription<dynamic> sub;
  sub = receive.listen((msg) {
    if (msg is SendPort) {
      if (!ready.isCompleted) ready.complete(msg);
      return;
    }
    if (msg is Map) {
      if (msg.containsKey('progress')) {
        final p = Map<String, Object?>.from(msg['progress'] as Map);
        onProgress?.call(
          ProgressEvent(
            phase: p['phase'] as String? ?? '',
            percent: p['percent'] as int? ?? 0,
            message: p['message'] as String? ?? '',
            seriesIndex: p['seriesIndex'] as int?,
            seriesTotal: p['seriesTotal'] as int?,
            frameIndex: p['frameIndex'] as int?,
            frameTotal: p['frameTotal'] as int?,
          ),
        );
        return;
      }
      if (msg['ok'] == true) {
        if (!done.isCompleted) done.complete(_resultFromMap(msg));
        return;
      }
      if (!done.isCompleted) {
        done.completeError(
          EngineException(
            msg['code'] as String? ?? EngineException.convertError,
            msg['error'] as String? ?? '转换失败',
            detail: msg['detail'] as String?,
          ),
        );
      }
    }
  });
  try {
    final send = await ready.future.timeout(const Duration(seconds: 10));
    send.send(<String, Object?>{
      'input': input.path,
      'output': outputDir.path,
      'format': params.format.name,
      'quality': params.quality.name,
      'merge': params.merge,
      'fps': params.fps,
      'ffmpegPath': ffmpegPath,
    });
    return await done.future;
  } finally {
    await sub.cancel();
    receive.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

/// Isolate entry (public so it can be spawned).
void convertIsolateMain(SendPort parent) {
  final port = ReceivePort();
  parent.send(port.sendPort);
  port.listen((msg) async {
    if (msg is! Map) return;
    try {
      final format = OutputFormat.values.byName(msg['format'] as String);
      final quality = Quality.values.byName(msg['quality'] as String);
      final result = await convertDicomPackage(
        input: File(msg['input'] as String),
        outputDir: Directory(msg['output'] as String),
        params: ConvertParams(
          format: format,
          quality: quality,
          merge: msg['merge'] as bool? ?? false,
          fps: msg['fps'] as int? ?? 10,
        ),
        ffmpegPath: msg['ffmpegPath'] as String?,
        onProgress: (e) => parent.send({
          'progress': {
            'phase': e.phase,
            'percent': e.percent,
            'message': e.message,
            'seriesIndex': e.seriesIndex,
            'seriesTotal': e.seriesTotal,
            'frameIndex': e.frameIndex,
            'frameTotal': e.frameTotal,
          },
        }),
      );
      parent.send({
        'ok': true,
        'fps': result.fps,
        'series': [
          for (final s in result.series)
            {
              'path': s.file.path,
              'frameCount': s.frameCount,
              'fps': s.fps,
              'width': s.width,
              'height': s.height,
              'kind': s.kind,
            },
        ],
      });
    } catch (e) {
      final err = convertErrorFrom(e);
      parent.send({
        'ok': false,
        'error': err.message,
        'code': err.code,
        'detail': err.detail,
      });
    }
  });
}

ConvertResult _resultFromMap(Map<dynamic, dynamic> msg) {
  final series = <SeriesArtifact>[];
  for (final item in (msg['series'] as List<dynamic>? ?? [])) {
    final m = Map<String, Object?>.from(item as Map);
    series.add(
      SeriesArtifact(
        file: File(m['path'] as String? ?? ''),
        frameCount: m['frameCount'] as int? ?? 0,
        fps: m['fps'] as int? ?? 10,
        width: m['width'] as int? ?? 0,
        height: m['height'] as int? ?? 0,
        kind: m['kind'] as String? ?? 'series',
      ),
    );
  }
  return ConvertResult(series: series, fps: msg['fps'] as int? ?? 10);
}
