import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/activity.dart';
import '../models/model_utils.dart';
import '../models/sync.dart';
import '../repositories/activity_repository.dart';
import '../repositories/sync_repository.dart';

/// 同步编排：触发同步、Mock 一键连接并同步、GPX 文件导入。
class SyncService {
  final SyncRepository _syncRepo;
  final ActivityRepository _activityRepo;

  SyncService(this._syncRepo, this._activityRepo);

  /// Mock：建立连接（已存在则复用）并立即触发一次同步。
  /// 返回同步结果 {jobId, added, skipped}。
  Future<Map<String, dynamic>> connectMockAndSync() async {
    String? connectionId;
    try {
      final Map<String, dynamic> res = await _syncRepo.connect('mock');
      final Map<String, dynamic> conn = asMap(res['connection']);
      connectionId = asString(conn['id']) ?? asString(res['id']);
    } catch (_) {
      connectionId = null; // 可能已存在（409），走下面查询
    }
    if (connectionId == null || connectionId.isEmpty) {
      final List<SyncConnection> connections =
          await _syncRepo.connections();
      for (final SyncConnection c in connections) {
        if (c.provider == 'mock') {
          connectionId = c.id;
          break;
        }
      }
    }
    if (connectionId == null || connectionId.isEmpty) {
      throw StateError('Mock 连接创建失败');
    }
    return _syncRepo.syncConnection(connectionId);
  }

  /// 选择 GPX 文件并导入；返回 null 表示用户取消。
  Future<ActivityImportResult?> pickAndImportGpx() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['gpx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile file = result.files.first;
    final List<int>? bytes = file.bytes;
    if (bytes == null) {
      throw StateError('无法读取文件内容：${file.name}');
    }
    final String base64Content = base64Encode(bytes);
    return _activityRepo.importFile(file.name, base64Content);
  }
}
