import 'package:dicomflow_app/domain/slice_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first slice is at t=0', () {
    expect(
      sliceFromPosition(position: Duration.zero, fps: 10, total: 5),
      1,
    );
    expect(positionForSlice(slice: 1, fps: 10), Duration.zero);
  });

  test('slice 5 at 10 fps is 400ms', () {
    final pos = positionForSlice(slice: 5, fps: 10);
    expect(pos, const Duration(milliseconds: 400));
    expect(sliceFromPosition(position: pos, fps: 10, total: 5), 5);
  });

  test('mid-frame stays on the current slice', () {
    expect(
      sliceFromPosition(
        position: const Duration(milliseconds: 50),
        fps: 10,
        total: 5,
      ),
      1,
    );
  });

  test('position past the last frame clamps', () {
    expect(
      sliceFromPosition(
        position: const Duration(seconds: 2),
        fps: 10,
        total: 5,
      ),
      5,
    );
  });
}
