import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../../providers/sync_provider.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common_widgets.dart';
import 'activity_detail.dart';
import 'activity_edit_page.dart';

/// 活动列表（分页 + provider 标签）；expanded 断点下列表 + 详情双栏。
class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedId;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ActivitiesProvider>().loadMore();
    }
  }

  Future<void> _importGpx() async {
    setState(() => _importing = true);
    String message;
    try {
      final ActivityImportResult? result =
          await context.read<SyncProvider>().importGpx();
      if (result == null) {
        message = '已取消选择';
      } else {
        message = '导入完成：新增 ${result.added} 条（${result.fileName}）';
        if (mounted) {
          await context.read<ActivitiesProvider>().refresh();
        }
      }
    } catch (e) {
      message = '导入失败：$e';
    }
    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ActivityEditPage()),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('活动已保存')),
    );
  }

  void _onTapActivity(Activity activity, bool expanded) {
    if (expanded) {
      setState(() => _selectedId = activity.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityDetailPage(activityId: activity.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool expanded = context.isExpanded;
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动'),
        actions: <Widget>[
          IconButton(
            tooltip: '导入 GPX',
            onPressed: _importing ? null : _importGpx,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: '手动录入',
            onPressed: _openEdit,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (expanded) {
            return Row(
              children: <Widget>[
                SizedBox(width: 360, child: _buildList(expanded: true)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedId == null
                      ? const EmptyState(
                          icon: Icons.directions_run,
                          title: '选择一条活动查看详情',
                        )
                      : ActivityDetailView(
                          key: ValueKey<String>(_selectedId),
                          activityId: _selectedId!,
                        ),
                ),
              ],
            );
          }
          return _buildList(expanded: false);
        },
      ),
    );
  }

  Widget _buildList({required bool expanded}) {
    return Consumer<ActivitiesProvider>(
      builder: (BuildContext context, ActivitiesProvider provider, _) {
        if (provider.loading && provider.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.items.isEmpty) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: '加载失败',
            message: provider.error,
            actionLabel: '重试',
            onAction: () => context.read<ActivitiesProvider>().refresh(),
          );
        }
        if (provider.items.isEmpty) {
          return EmptyState(
            icon: Icons.directions_run_outlined,
            title: '暂无活动',
            message: '可手动录入、导入 GPX 文件，或在「我的 → 数据连接」一键同步 Mock 数据。',
            actionLabel: '手动录入',
            onAction: _openEdit,
          );
        }
        // 双栏模式下选中项被删除时清除选择
        if (_selectedId != null &&
            !provider.items.any((Activity a) => a.id == _selectedId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedId = null);
          });
        }
        return RefreshIndicator(
          onRefresh: () => context.read<ActivitiesProvider>().refresh(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: provider.items.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == provider.items.length) {
                if (provider.loadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      provider.hasMore
                          ? '上拉加载更多'
                          : '共 ${provider.total} 条',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              }
              final Activity activity = provider.items[index];
              return ActivityTile(
                activity: activity,
                selected: expanded && activity.id == _selectedId,
                onTap: () => _onTapActivity(activity, expanded),
              );
            },
          ),
        );
      },
    );
  }
}
