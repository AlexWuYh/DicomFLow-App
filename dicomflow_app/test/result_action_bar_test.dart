import 'dart:io';

import 'package:dicomflow_app/engine/pipeline.dart';
import 'package:dicomflow_app/ui/theme.dart';
import 'package:dicomflow_app/ui/widgets/result_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('share label says this file, not all results', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_share_label_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final file = File('${tmp.path}/series.mp4')..writeAsBytesSync(const [1]);
    final artifact = SeriesArtifact(
      file: file,
      frameCount: 5,
      fps: 10,
      width: 8,
      height: 8,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ResultActionBar(
            selected: artifact,
            allFiles: [file],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('分享此文件'), findsOneWidget);
    expect(find.textContaining('不是全部结果'), findsOneWidget);
    expect(find.text('分享给医生'), findsNothing);
    expect(find.text('导出到文件夹'), findsOneWidget);
    expect(find.text('在文件夹中显示'), findsOneWidget);
    expect(find.text('保存到文件'), findsNothing);
    expect(find.byIcon(Icons.save_alt), findsNothing);
  });

  testWidgets('compact bar still explains share is the current file', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_share_compact_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final file = File('${tmp.path}/series.mp4')..writeAsBytesSync(const [1]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ResultActionBar(
            selected: SeriesArtifact(
              file: file,
              frameCount: 5,
              fps: 10,
              width: 8,
              height: 8,
            ),
            allFiles: [file],
            compact: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('分享此文件'), findsOneWidget);
    expect(find.textContaining('不是全部结果'), findsOneWidget);
    expect(find.text('导出到文件夹'), findsOneWidget);
    expect(find.text('保存到文件'), findsNothing);
    expect(find.text('在文件夹中显示'), findsNothing);
    expect(find.byIcon(Icons.save_alt), findsNothing);
  });
}
