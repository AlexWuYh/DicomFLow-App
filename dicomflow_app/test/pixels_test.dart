import 'dart:typed_data';

import 'package:dicomflow_app/engine/pixels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jpeg fragments split on each SOI', () {
    final a = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
    final b = Uint8List.fromList([0xFF, 0xD8, 3, 4]);
    final frames = jpegPayloadsFromFragments([
      Uint8List(0),
      a,
      Uint8List.fromList([5, 6]),
      b,
    ]);
    expect(frames, hasLength(2));
    expect(frames[0], Uint8List.fromList([0xFF, 0xD8, 1, 2, 5, 6]));
    expect(frames[1], b);
  });

  test('deplanarize interleaves RGB planes', () {
    // RRR GGG BBB for 1x3
    final planar = [1, 1, 1, 2, 2, 2, 3, 3, 3];
    final interleaved = deplanarize(planar, 3, 1, 3);
    expect(interleaved, [1, 2, 3, 1, 2, 3, 1, 2, 3]);
  });
}
