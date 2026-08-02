import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/zone_widgets.dart';
import 'connections_page.dart';
import 'profile_edit_page.dart';

String _genderLabel(String? gender) {
  switch (gender) {
    case 'male':
      return '男';
    case 'female':
      return '女';
    case 'other':
      return '其他';
    default:
      return '--';
  }
}

/// 我的：档案、心率区间、数据连接、同步记录、设置/退出登录。
class MePage extends StatelessWidget {
  const MePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirm != true) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Consumer<ProfileProvider>(
        builder: (BuildContext context, ProfileProvider provider, _) {
          final Profile? profile = provider.profile;
          return RefreshIndicator(
            onRefresh: () => context.read<ProfileProvider>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.person, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile?.nickname ??
                                user?.nickname ??
                                '跑者',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(user?.email ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (provider.loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SectionHeader(title: '个人档案'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: <Widget>[
                        if (provider.error != null && profile == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '档案加载失败：${provider.error}',
                              style: const TextStyle(
                                  color: AppColors.heartRed, fontSize: 12),
                            ),
                          ),
                        InfoRow(
                            label: '性别',
                            value: _genderLabel(profile?.gender)),
                        InfoRow(
                            label: '出生日期',
                            value: profile?.birthDate ?? '--'),
                        InfoRow(
                            label: '身高',
                            value: profile?.heightCm != null
                                ? '${profile!.heightCm!.toStringAsFixed(0)} cm'
                                : '--'),
                        InfoRow(
                            label: '体重',
                            value: profile?.weightKg != null
                                ? '${profile!.weightKg!.toStringAsFixed(1)} kg'
                                : '--'),
                        InfoRow(
                            label: '静息心率',
                            value: profile?.restingHr != null
                                ? '${profile!.restingHr} bpm'
                                : '--'),
                        InfoRow(
                            label: '最大心率',
                            value: profile?.maxHr != null
                                ? '${profile!.maxHr} bpm'
                                : '--'),
                        InfoRow(
                            label: '当前周跑量',
                            value: profile?.weeklyKm != null
                                ? '${profile!.weeklyKm!.toStringAsFixed(0)} km'
                                : '--'),
                        InfoRow(
                            label: '跑龄',
                            value: profile?.yearsRunning != null
                                ? '${profile!.yearsRunning!.toStringAsFixed(1)} 年'
                                : '--'),
                        const Divider(height: 20),
                        Row(
                          children: <Widget>[
                            Expanded(child: _pbChip('5K', profile?.pb5kSec)),
                            Expanded(child: _pbChip('10K', profile?.pb10kSec)),
                            Expanded(
                                child: _pbChip('半马', profile?.pbHalfSec)),
                            Expanded(
                                child: _pbChip('全马', profile?.pbFullSec)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ProfileEditPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('编辑档案'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionHeader(title: '心率区间'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: provider.zones.isEmpty
                        ? const Text('完善最大心率与静息心率后，将按储备心率法自动计算区间。')
                        : Column(
                            children: <Widget>[
                              ...provider.zones.map(
                                  (HrZone z) => HrZoneRow(zone: z)),
                              const SizedBox(height: 6),
                              Text(
                                '储备心率法（Karvonen）自动计算',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                  ),
                ),
                const SectionHeader(title: '数据与同步'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sync, color: AppColors.primary),
                    title: const Text('数据连接'),
                    subtitle: const Text('高驰授权 · Mock 数据 · GPX 导入 · 同步历史'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ConnectionsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SectionHeader(title: '设置'),
                Card(
                  child: Column(
                    children: <Widget>[
                      const ListTile(
                        leading: Icon(Icons.cloud_outlined),
                        title: Text('API 地址'),
                        subtitle: Text(ApiClient.baseUrl),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout,
                            color: AppColors.heartRed),
                        title: const Text('退出登录',
                            style: TextStyle(color: AppColors.heartRed)),
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pbChip(String label, int? sec) {
    return Builder(
      builder: (BuildContext context) => Column(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            sec != null ? formatDuration(sec) : '--',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
