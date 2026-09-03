import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class GifPreviewFrames {
  const GifPreviewFrames({
    required this.width,
    required this.height,
    required this.frames,
  });

  final int width;
  final int height;
  final List<Uint8List> frames;
}

/// Decode a GIF and PNG-encode each frame. Safe as a `compute` / isolate entry.
GifPreviewFrames decodeGifPreviewFile(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeGif(bytes);
  if (decoded == null || decoded.frames.isEmpty) {
    throw StateError('GIF 无法解码');
  }
  return GifPreviewFrames(
    width: decoded.width,
    height: decoded.height,
    frames: [
      for (final frame in decoded.frames) Uint8List.fromList(img.encodePng(frame, level: 1)),
    ],
  );
}

/// Sendable map for isolate / `compute` (custom classes may not cross isolates).
Map<String, dynamic> decodeGifPreviewPayload(String path) {
  final preview = decodeGifPreviewFile(path);
  return {
    'width': preview.width,
    'height': preview.height,
    'frames': preview.frames,
  };
}

Future<GifPreviewFrames> loadGifPreview(String path) async {
  try {
    final raw = await compute(decodeGifPreviewPayload, path);
    return _fromPayload(raw);
  } catch (_) {
    return decodeGifPreviewFile(path);
  }
}

GifPreviewFrames _fromPayload(Map<String, dynamic> payload) {
  final frames = payload['frames'];
  if (frames is! List || frames.isEmpty) {
    throw StateError('GIF 无法解码');
  }
  return GifPreviewFrames(
    width: (payload['width'] as num?)?.toInt() ?? 0,
    height: (payload['height'] as num?)?.toInt() ?? 0,
    frames: [for (final frame in frames) _asBytes(frame)],
  );
}

Uint8List _asBytes(Object? frame) {
  if (frame is Uint8List) return frame;
  if (frame is TypedData) {
    return Uint8List.view(frame.buffer, frame.offsetInBytes, frame.lengthInBytes);
  }
  if (frame is List<int>) return Uint8List.fromList(frame);
  throw StateError('GIF 帧格式无效');
}
