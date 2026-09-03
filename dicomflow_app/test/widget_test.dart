import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dicomflow_app/history/job_store.dart';
import 'package:dicomflow_app/history/jobs_controller.dart';
import 'package:dicomflow_app/ui/app.dart';
import 'package:dicomflow_app/ui/settings_page.dart';
import 'package:dicomflow_app/ui/theme.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    JobsController? jobs,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
        child: DicomFlowApp(showSplash: false, jobs: jobs),
      ),
    );
    await tester.pump();
  }

  testWidgets('splash shows brand then yields workspace', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
        child: const DicomFlowApp(splashDuration: Duration(milliseconds: 40)),
      ),
    );
    await tester.pump();
    expect(find.text('影像随手看'), findsWidgets);
    expect(find.text('打开医院给的压缩包'), findsNothing);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();
    expect(find.text('打开医院给的压缩包'), findsOneWidget);
  });

  testWidgets('convert workspace shows empty state and disabled start', (tester) async {
    await pumpApp(tester);

    expect(find.text('DicomFlow'), findsWidgets);
    expect(find.text('打开医院给的压缩包'), findsOneWidget);
    expect(find.text('选择压缩包'), findsOneWidget);
    expect(find.text('转换流程'), findsOneWidget);
    expect(find.textContaining('选压缩包'), findsOneWidget);
    expect(find.textContaining('本机转换'), findsOneWidget);
    expect(find.textContaining('预览导出'), findsOneWidget);

    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始转换'),
    );
    expect(start.onPressed, isNull);

    expect(find.text('转换'), findsWidgets);
    expect(find.text('历史'), findsOneWidget);
  });

  testWidgets('desktop shell uses a navigation rail', (tester) async {
    await pumpApp(tester, size: const Size(1100, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('打开医院给的压缩包'), findsOneWidget);
  });

  testWidgets('history tab shows empty state', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_hist_empty_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final jobs = JobsController(
      store: JobStore(File('${dir.path}/jobs.json')),
      settingsFile: File('${dir.path}/settings.json'),
    );
    await pumpApp(tester, jobs: jobs);

    await tester.tap(find.text('历史').last);
    await tester.pump();

    expect(find.text('还没有转换记录'), findsOneWidget);
    expect(find.textContaining('转换完成后会出现在这里'), findsOneWidget);
    expect(find.textContaining('记录保留 7天'), findsOneWidget);
    expect(find.textContaining('过期会从本机删除'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('1天'), findsNothing);
    expect(find.byTooltip('设置'), findsOneWidget);
  });

  testWidgets('settings page lists retention options without applying on tap', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: SettingsPage(jobs: JobsController()),
        ),
      ),
    );

    expect(find.text('1天'), findsOneWidget);
    expect(find.text('7天'), findsWidgets);
    expect(find.text('30天'), findsOneWidget);
    expect(find.textContaining('缩短天数时需再次确认才会清理'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存')).onPressed, isNull);

    await tester.tap(find.text('1天'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存')).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    expect(find.text('确认缩短保留时间？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(find.text('确认缩短保留时间？'), findsNothing);
  });

  testWidgets('about tab shows intro author license and source links', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('关于'));
    await tester.pump();

    expect(find.text('简介'), findsOneWidget);
    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('历史保留时间'), findsOneWidget);
    expect(find.text('@AlexWuYh'), findsOneWidget);
    expect(find.byKey(const Key('author-avatar')), findsOneWidget);
    expect(find.textContaining('github.com/AlexWuYh', skipOffstage: false), findsWidgets);
    expect(find.textContaining('github.com/AlexWuYh/DicomFLow-App', skipOffstage: false), findsWidgets);
    expect(find.textContaining('MIT', skipOffstage: false), findsWidgets);
    expect(find.textContaining('GPL-3.0', skipOffstage: false), findsWidgets);
    expect(find.text('线上网页版'), findsNothing);
  });

  testWidgets('desktop about shows all sections without scrolling', (tester) async {
    await pumpApp(tester, size: const Size(1280, 840));
    await tester.tap(find.text('关于'));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('简介'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(find.text('开源项目'), findsOneWidget);
    expect(find.text('许可'), findsOneWidget);
    expect(find.textContaining('MIT'), findsWidgets);
    expect(find.textContaining('GPL-3.0'), findsWidgets);
    expect(find.text('@AlexWuYh'), findsOneWidget);
    expect(find.byKey(const Key('author-avatar')), findsOneWidget);
  });

  testWidgets('theme toggle switches brightness', (tester) async {
    await pumpApp(tester);

    final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(before.themeMode, ThemeMode.light);

    await tester.tap(find.byTooltip('切换到深色主题'));
    await tester.pump();

    final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(after.themeMode, ThemeMode.dark);
  });
}
