import 'package:dicomflow_app/ui/theme.dart';
import 'package:dicomflow_app/ui/widgets/preview_file_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    PreviewFileItem(
      id: 'a',
      title: 'series_a.mp4',
      subtitle: '10 片 · 10 fps',
      icon: Icons.movie_outlined,
    ),
    PreviewFileItem(
      id: 'b',
      title: 'series_b.mp4',
      subtitle: '8 片 · 10 fps',
      icon: Icons.movie_outlined,
    ),
    PreviewFileItem(
      id: 'c',
      title: 'all.zip',
      subtitle: '打包全部序列',
      icon: Icons.folder_zip_outlined,
    ),
  ];

  Future<void> pumpSwitcher(WidgetTester tester, {required ValueChanged<String> onSelected, String selected = 'a'}) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: PreviewFileSwitcher(
            items: files,
            selectedId: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('shows position and steps to the next file', (tester) async {
    var selected = 'a';
    await pumpSwitcher(tester, selected: selected, onSelected: (id) => selected = id);
    await tester.pump();
    expect(find.text('文件 1 / 3'), findsOneWidget);
    expect(find.text('series_a.mp4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-file-next')));
    await tester.pump();
    expect(selected, 'b');
  });

  testWidgets('opens a sheet listing every file', (tester) async {
    var selected = 'a';
    await pumpSwitcher(
      tester,
      selected: selected,
      onSelected: (id) => selected = id,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('preview-file-open-list')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('选择文件 · 3'), findsOneWidget);
    expect(find.text('series_b.mp4'), findsOneWidget);
    expect(find.text('all.zip'), findsOneWidget);

    await tester.tap(find.text('all.zip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, 'c');
  });
}
