import 'package:dicomflow_app/ui/theme.dart';
import 'package:dicomflow_app/ui/viewer/slice_scrub_bar.dart';
import 'package:dicomflow_app/ui/viewer/zoomable_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrub bar shows current / total slices', (tester) async {
    var current = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SliceScrubBar(
                current: current,
                total: 5,
                playing: false,
                onChanged: (v) => setState(() => current = v),
                onPlayPause: () {},
              );
            },
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('slice-index-label')), findsOneWidget);
    expect(find.text('1 / 5'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: SliceScrubBar(
            current: 3,
            total: 5,
            playing: false,
            onChanged: (_) {},
            onPlayPause: () {},
          ),
        ),
      ),
    );
    expect(find.text('3 / 5'), findsWidgets);
  });

  testWidgets('zoomable stage scales to 2x then resets to 1x', (tester) async {
    final key = GlobalKey<ZoomableStageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: ZoomableStage(
              key: key,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.scale, 1);

    key.currentState!.zoomTo(2, focal: const Offset(80, 80));
    await tester.pump();
    expect(key.currentState!.scale, closeTo(2.0, 0.15));

    key.currentState!.reset();
    await tester.pump();
    expect(key.currentState!.scale, closeTo(1.0, 0.15));
  });

  testWidgets('zoom in and out buttons change scale', (tester) async {
    final key = GlobalKey<ZoomableStageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: ZoomableStage(
              key: key,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    key.currentState!.zoomIn();
    await tester.pump();
    expect(key.currentState!.scale, greaterThan(1.1));
    key.currentState!.zoomOut();
    await tester.pump();
    expect(key.currentState!.scale, closeTo(1.0, 0.2));
  });
}
