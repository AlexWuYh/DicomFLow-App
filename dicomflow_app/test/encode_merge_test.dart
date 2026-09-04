import 'package:dicomflow_app/engine/encode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merged frame count inserts 0.4s of black between series', () {
    expect(mergedBlackFrameCount(10), 4);
    expect(mergedOutputFrameCount(const [2, 2], 10), 8);
    expect(mergedOutputFrameCount(const [2, 2, 2], 10), 14);
  });

  test('concat filter letterboxes series and reuses black clips', () {
    final graph = mergeConcatFilterGraph(
      seriesCount: 2,
      width: 16,
      height: 8,
      fps: 10,
    );
    expect(graph, contains('[0:v]scale=16:8:force_original_aspect_ratio=decrease'));
    expect(graph, contains('pad=16:8:(ow-iw)/2:(oh-ih)/2:black'));
    expect(graph, contains('[1:v]setsar=1,fps=10,format=yuv420p[s1]'));
    expect(graph, contains('[s0][s1][s2] concat=n=3:v=1:a=0[v]'));
  });

  test('mp4 H.264 flags are Windows Media Foundation friendly', () {
    final args = mp4H264OutputArgs(crf: 23, outputPath: 'out.mp4');
    expect(args, containsAllInOrder(['-profile:v', 'main']));
    expect(args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
    expect(args, containsAllInOrder(['-movflags', '+faststart']));
    expect(args.last, 'out.mp4');
  });
}
