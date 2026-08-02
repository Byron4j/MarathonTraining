import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'providers/activities_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/sync_provider.dart';
import 'repositories/activity_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/plan_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/sync_repository.dart';
import 'services/plan_service.dart';
import 'services/sync_service.dart';
import 'ui/pages/home_shell.dart';
import 'ui/pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Storage storage = await Storage.create();
  final ApiClient apiClient = ApiClient(storage);

  final AuthRepository authRepo = AuthRepository(apiClient);
  final ProfileRepository profileRepo = ProfileRepository(apiClient);
  final ActivityRepository activityRepo = ActivityRepository(apiClient);
  final PlanRepository planRepo = PlanRepository(apiClient);
  final StatsRepository statsRepo = StatsRepository(apiClient);
  final SyncRepository syncRepo = SyncRepository(apiClient);

  final PlanService planService = PlanService(planRepo);
  final SyncService syncService = SyncService(syncRepo, activityRepo);

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(authRepo, storage, apiClient)..bootstrap(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(profileRepo),
        ),
        ChangeNotifierProvider<ActivitiesProvider>(
          create: (_) => ActivitiesProvider(activityRepo),
        ),
        ChangeNotifierProvider<PlanProvider>(
          create: (_) => PlanProvider(planRepo, planService),
        ),
        ChangeNotifierProvider<StatsProvider>(
          create: (_) => StatsProvider(statsRepo),
        ),
        ChangeNotifierProvider<SyncProvider>(
          create: (_) => SyncProvider(syncRepo, syncService),
        ),
      ],
      child: const PaceForgeApp(),
    ),
  );
}

class PaceForgeApp extends StatelessWidget {
  const PaceForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceForge',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system, // 深色优先，浅色全套
      home: const RootGate(),
    );
  }
}

/// 根据认证状态切换：启动页 / 登录页 / 主框架
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthStatus status = context.watch<AuthProvider>().status;
    switch (status) {
      case AuthStatus.authenticated:
        return const HomeShell();
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.directions_run,
                    size: 56, color: AppColors.primary),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
    }
  }
}
