import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../history/jobs_controller.dart';
import 'about_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'splash_page.dart';
import 'theme.dart';
import 'widgets/brand_mark.dart';

class DicomFlowApp extends StatefulWidget {
  const DicomFlowApp({
    super.key,
    this.jobs,
    this.showSplash = true,
    this.splashDuration = const Duration(milliseconds: 1600),
  });

  final JobsController? jobs;
  final bool showSplash;
  final Duration splashDuration;

  @override
  State<DicomFlowApp> createState() => _DicomFlowAppState();
}

class _DicomFlowAppState extends State<DicomFlowApp> {
  ThemeMode _themeMode = ThemeMode.light;
  int _tabIndex = 0;
  late bool _showSplash = widget.showSplash;
  late final JobsController _jobs = widget.jobs ?? JobsController();

  @override
  void initState() {
    super.initState();
    _jobs.ensureStore();
    if (widget.showSplash) {
      Future<void>.delayed(widget.splashDuration, () {
        if (mounted) setState(() => _showSplash = false);
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = _themeMode == ThemeMode.dark;
    return MaterialApp(
      title: 'DicomFlow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _showSplash
            ? SystemUiOverlayStyle.light
            : (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
        child: _showSplash
            ? const SplashPage()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= AppLayout.desktopBreakpoint;
                  final pages = [
                    HomePage(onToggleTheme: _toggleTheme, jobs: _jobs),
                    HistoryPage(jobs: _jobs),
                    AboutPage(jobs: _jobs),
                  ];
                  if (desktop) {
                    return Scaffold(
                      body: Row(
                        children: [
                          NavigationRail(
                            selectedIndex: _tabIndex,
                            onDestinationSelected: (index) => setState(() => _tabIndex = index),
                            labelType: NavigationRailLabelType.all,
                            groupAlignment: -0.85,
                            leading: const Padding(
                              padding: EdgeInsets.fromLTRB(0, 8, 0, 20),
                              child: BrandMark(size: 40),
                            ),
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.movie_creation_outlined),
                                selectedIcon: Icon(Icons.movie_creation),
                                label: Text('转换'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.history_outlined),
                                selectedIcon: Icon(Icons.history),
                                label: Text('历史'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.info_outline),
                                selectedIcon: Icon(Icons.info),
                                label: Text('关于'),
                              ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: IndexedStack(index: _tabIndex, children: pages),
                          ),
                        ],
                      ),
                    );
                  }
                  return Scaffold(
                    body: IndexedStack(index: _tabIndex, children: pages),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: _tabIndex,
                      onDestinationSelected: (index) => setState(() => _tabIndex = index),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.movie_creation_outlined),
                          selectedIcon: Icon(Icons.movie_creation),
                          label: '转换',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.history),
                          selectedIcon: Icon(Icons.history),
                          label: '历史',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.info_outline),
                          selectedIcon: Icon(Icons.info),
                          label: '关于',
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
