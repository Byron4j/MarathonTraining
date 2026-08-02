import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../models/sync.dart';
import '../../providers/sync_provider.dart';
import '../widgets/common_widgets.dart';

/// 数据连接：高驰授权 / Mock 一键连接并同步 / GPX 导入 / 连接管理 / 同步历史。
class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  bool _importing = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _authorizeCoros() async {
    final SyncProvider provider = context.read<SyncProvider>();
    final String? url = await provider.corosAuthorizeUrl();
    if (!mounted) return;
    if (url == null) {
      _snack(provider.error ?? '获取授权链接失败');
      return;
    }
    final bool launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    _snack(launched ? '请在浏览器中完成高驰授权，完成后返回下拉刷新' : '无法打开浏览器');
  }

  Future<void> _connectMock() async {
    final SyncProvider provider = context.read<SyncProvider>();
    final String? message = await provider.connectMockAndSync();
    if (!mounted) return;
    _snack(message ?? provider.error ?? '同步失败');
  }

  Future<void> _importGpx() async {
    setState(() => _importing = true);
    try {
      final ActivityImportResult? result =
          await context.read<SyncProvider>().importGpx();
      if (!mounted) return;
      _snack(result == null
          ? '已取消选择'
          : '导入完成：新增 ${result.added} 条（${result.fileName}）');
    } catch (e) {
      if (!mounted) return;
      _snack('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _syncConnection(SyncConnection connection) async {
    final SyncProvider provider = context.read<SyncProvider>();
    final String? message = await provider.syncConnection(connection.id);
    if (!mounted) return;
    _snack(message ?? provider.error ?? '同步失败');
  }

  Future<void> _disconnect(SyncConnection connection) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('断开${providerLabel(connection.provider)}连接'),
        content: const Text('断开后将不再同步该平台数据，已同步的活动保留。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('断开'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    final bool ok =
        await context.read<SyncProvider>().disconnect(connection.id);
    if (!mounted) return;
    _snack(ok ? '已断开连接' : (context.read<SyncProvider>().error ?? '操作失败'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据连接')),
      body: Consumer<SyncProvider>(
        builder: (BuildContext context, SyncProvider provider, _) {
          final SyncProviderInfo? coros = provider.providerInfo('coros');
          final bool corosAvailable = coros?.available ?? true;
          return RefreshIndicator(
            onRefresh: () => context.read<SyncProvider>().loadAll(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (provider.loading)
                  const LinearProgressIndicator(),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(
                          color: AppColors.heartRed, fontSize: 12),
                    ),
                  ),
                const SectionHeader(title: '数据来源'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.watch,
                        color: AppColors.primary),
                    title: const Text('高驰 COROS'),
                    subtitle: Text(corosAvailable
                        ? 'OAuth2 授权后自动同步运动数据'
                        : '需在 open.coros.com 申请企业开发者凭据（COROS_CLIENT_ID / SECRET）后可用'),
                    trailing: corosAvailable
                        ? FilledButton.tonal(
                            onPressed:
                                provider.loading ? null : _authorizeCoros,
                            child: const Text('授权连接'),
                          )
                        : const Chip(label: Text('未配置')),
                    onTap: corosAvailable ? _authorizeCoros : null,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.science_outlined,
                        color: AppColors.secondary),
                    title: const Text('模拟数据 Mock'),
                    subtitle: const Text('一键生成近 8 周拟真训练数据，便于无设备体验'),
                    trailing: provider.syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton.tonal(
                            onPressed: _connectMock,
                            child: const Text('连接并同步'),
                          ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.upload_file,
                        color: Color(0xFF4A9DFF)),
                    title: const Text('文件导入（GPX）'),
                    subtitle: const Text('佳明 / 华为 / 高驰均可导出 GPX'),
                    trailing: _importing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton.tonal(
                            onPressed: _importGpx,
                            child: const Text('选择文件'),
                          ),
                  ),
                ),
                const SectionHeader(title: '我的连接'),
                if (provider.connections.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无连接。'),
                    ),
                  )
                else
                  ...provider.connections.map(
                    (SyncConnection c) => Card(
                      child: ListTile(
                        leading: Icon(
                          c.status == 'connected'
                              ? Icons.link
                              : Icons.link_off,
                          color: c.status == 'connected'
                              ? AppColors.primary
                              : AppColors.heartRed,
                        ),
                        title: Text(providerLabel(c.provider)),
                        subtitle: Text(
                          '状态 ${c.status}'
                          '${c.lastSyncAt != null ? ' · 上次同步 ${formatDateTime(c.lastSyncAt)}' : ''}'
                          '${c.lastError != null ? '\n${c.lastError}' : ''}',
                        ),
                        isThreeLine: c.lastError != null,
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: '立即同步',
                              icon: const Icon(Icons.sync),
                              onPressed: provider.syncing
                                  ? null
                                  : () => _syncConnection(c),
                            ),
                            IconButton(
                              tooltip: '断开',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _disconnect(c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SectionHeader(title: '同步历史'),
                if (provider.jobs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无同步记录。'),
                    ),
                  )
                else
                  ...provider.jobs.map(
                    (SyncJob job) => Card(
                      child: ListTile(
                        leading: Icon(
                          job.status == 'success' || job.errorMsg == null
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color:
                              job.status == 'success' || job.errorMsg == null
                                  ? AppColors.primary
                                  : AppColors.heartRed,
                        ),
                        title: Text(
                          '${providerLabel(job.provider)} · 新增 ${job.added} · 跳过 ${job.skipped}',
                        ),
                        subtitle: Text(
                          '${formatDateTime(job.startedAt)}'
                          '${job.errorMsg != null ? ' · ${job.errorMsg}' : ''}',
                        ),
                      ),
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
}
