import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';

/// FFmpegKit backend for Android (and as a fallback). Must only be wired from
/// the root isolate — platform channels cannot run inside [Isolate.spawn].
Future<ProcessResult> ffmpegProcessKit(
  List<String> args, {
  String? ffmpegPath,
}) async {
  final session = await FFmpegKit.executeWithArguments(args);
  final code = await session.getReturnCode();
  final output = await session.getOutput() ?? '';
  final logs = await session.getAllLogsAsString() ?? output;
  final value = code?.getValue() ?? 1;
  final ok = ReturnCode.isSuccess(code);
  return ProcessResult(0, ok ? 0 : value, output, logs);
}

Future<ProcessResult> ffprobeProcessKit(List<String> args) async {
  final session = await FFprobeKit.executeWithArguments(args);
  final code = await session.getReturnCode();
  final output = await session.getOutput() ?? '';
  final value = code?.getValue() ?? 1;
  final ok = ReturnCode.isSuccess(code);
  return ProcessResult(0, ok ? 0 : value, output, output);
}
