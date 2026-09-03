import 'dart:io';

import 'package:dicomflow_app/ui/viewer/gif_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

File _writeTinyGif() {
  final dir = Directory.systemTemp.createTempSync('dicomflow_gif_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final frame = img.Image(width: 4, height: 4);
  frame.clear(img.ColorRgb8(10, 20, 30));
  return File('${dir.path}/tiny.gif')..writeAsBytesSync(img.encodeGif(frame));
}

void main() {
  test('decodeGifPreviewFile returns png frames', () {
    final file = _writeTinyGif();
    final preview = decodeGifPreviewFile(file.path);
    expect(preview.width, 4);
    expect(preview.height, 4);
    expect(preview.frames, isNotEmpty);
    expect(preview.frames.first, isNotEmpty);
  });

  test('loadGifPreview returns frames via compute payload', () async {
    final file = _writeTinyGif();
    final preview = await loadGifPreview(file.path);
    expect(preview.frames, hasLength(1));
    expect(preview.width, 4);
  });
}
