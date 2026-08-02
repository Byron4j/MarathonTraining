import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/activity.dart';
import '../models/sync.dart';
import '../repositories/sync_repository.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository _repo;
  final SyncService _service;

  List<SyncProviderInfo> providers = <SyncProviderInfo>[];
  List<SyncConnection> connections = <SyncConnection>[];
  List<SyncJob> jobs = <SyncJob>[];
  bool loading = false;
  bool syncing = false;
  String? error;

  SyncProvider(this._repo, this._service);

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      providers = await _repo.providers();
      connections = await _repo.connections();
      jobs = await _repo.jobs();
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  SyncProviderInfo? providerInfo(String key) {
    for (final SyncProviderInfo p in providers) {
      if (p.key == key) return p;
    }
    return null;
  }

  SyncConnection? connectionOf(String providerKey) {
    for (final SyncConnection c in connections) {
      if (c.provider == providerKey) return c;
    }
    return null;
  }

  /// 高驰授权链接（打开系统浏览器）
  Future<String?> corosAuthorizeUrl() async {
    try {
      return await _repo.corosAuthorizeUrl();
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Mock 一键连接并同步 → 返回结果文本
  Future<String?> connectMockAndSync() async {
    syncing = true;
    error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> result = await _service.connectMockAndSync();
      await loadAll();
      final dynamic added = result['added'] ?? 0;
      final dynamic skipped = result['skipped'] ?? 0;
      return '同步完成：新增 $added 条，跳过 $skipped 条';
    } catch (e) {
      error = apiErrorMessage(e);
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<String?> syncConnection(String connectionId) async {
    syncing = true;
    error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> result =
          await _repo.syncConnection(connectionId);
      await loadAll();
      final dynamic added = result['added'] ?? 0;
      final dynamic skipped = result['skipped'] ?? 0;
      return '同步完成：新增 $added 条，跳过 $skipped 条';
    } catch (e) {
      error = apiErrorMessage(e);
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<bool> disconnect(String connectionId) async {
    try {
      await _repo.disconnect(connectionId);
      connections = connections.where((c) => c.id != connectionId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// GPX 文件导入；返回 null 表示用户取消选择
  Future<ActivityImportResult?> importGpx() => _service.pickAndImportGpx();
}
