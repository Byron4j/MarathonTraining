import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../providers/activities_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/sync_provider.dart';
import 'activities_page.dart';
import 'dashboard_page.dart';
import 'me_page.dart';
import 'plan_page.dart';

/// 主框架页：按断点切换 NavigationBar / NavigationRail / 侧边栏。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    PlanPage(),
    ActivitiesPage(),
    MePage(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: '仪表盘',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: '计划',
    ),
    NavigationDestination(
      icon: Icon(Icons.directions_run_outlined),
      selectedIcon: Icon(Icons.directions_run),
      label: '活动',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 进入主框架后加载各模块数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StatsProvider>().load();
      context.read<ProfileProvider>().load();
      context.read<PlanProvider>().loadPlans();
      context.read<ActivitiesProvider>().refresh();
      context.read<SyncProvider>().loadAll();
    });
  }

  void _onSelect(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppBreakpoint bp = breakpointForWidth(constraints.maxWidth);
        final Widget body = IndexedStack(index: _index, children: _pages);

        if (bp == AppBreakpoint.compact) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              destinations: _destinations,
            ),
          );
        }

        if (bp == AppBreakpoint.medium) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _onSelect,
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map(
                        (NavigationDestination d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // expanded：侧边栏 + 内容
        return Scaffold(
          body: Row(
            children: <Widget>[
              Container(
                width: 240,
                color: AppColors.surfaceDark,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.directions_run,
                                color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'PaceForge',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: NavigationRail(
                          extended: true,
                          minExtendedWidth: 240,
                          backgroundColor: Colors.transparent,
                          selectedIndex: _index,
                          onDestinationSelected: _onSelect,
                          destinations: _destinations
                              .map(
                                (NavigationDestination d) =>
                                    NavigationRailDestination(
                                  icon: d.icon,
                                  selectedIcon: d.selectedIcon,
                                  label: Text(d.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
