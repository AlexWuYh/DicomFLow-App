import 'dart:typed_data';

import 'package:dicomflow_app/engine/window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window maps stored value using W/L like DicomFlow', () {
    final out = applyWindowToPixels(
      stored: const [40],
      slope: 1,
      intercept: 0,
      windowCenter: 100,
      windowWidth: 200,
      monochrome1: false,
    );
    // lower=0 upper=200 → 40/200*255 = 51
    expect(out.single, 51);
  });

  test('filename W/L parses as (center, width)', () {
    final parsed = windowFromFilename('CT_W400L40.dcm');
    expect(parsed, isNotNull);
    expect(parsed!.$1, 40);
    expect(parsed.$2, 400);
  });

  test('MONOCHROME1 inverts', () {
    final out = applyWindowToPixels(
      stored: const [40],
      slope: 1,
      intercept: 0,
      windowCenter: 100,
      windowWidth: 200,
      monochrome1: true,
    );
    expect(out.single, 255 - 51);
  });

  test('toRgbEven pads odd sizes', () {
    final gray = Uint8List.fromList(List<int>.filled(3 * 3, 10));
    final framed = toRgbEven(
      grayOrRgb: gray,
      width: 3,
      height: 3,
      samplesPerPixel: 1,
    );
    expect(framed.width, 4);
    expect(framed.height, 4);
    expect(framed.rgb.length, 4 * 4 * 3);
  });

  test('fitPad letterboxes onto a larger canvas', () {
    final src = toRgbEven(
      grayOrRgb: Uint8List.fromList(List<int>.filled(4 * 2, 200)),
      width: 4,
      height: 2,
      samplesPerPixel: 1,
    );
    final padded = fitPad(src, 8, 8);
    expect(padded.width, 8);
    expect(padded.height, 8);
    expect(padded.rgb[0], 0);
  });
}
