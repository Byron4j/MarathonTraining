import 'model_utils.dart';

/// 同步 Provider 信息（/sync/providers）
class SyncProviderInfo {
  final String key;
  final String name;
  final String? description;
  final bool available;
  final String? status;
  final List<String> capabilities;

  const SyncProviderInfo({
    required this.key,
    required this.name,
    this.description,
    this.available = true,
    this.status,
    this.capabilities = const <String>[],
  });

  factory SyncProviderInfo.fromJson(Map<String, dynamic> json) {
    final String? status = asString(json['status']);
    final bool available = json['available'] is bool
        ? json['available'] as bool
        : status != 'unavailable';
    final List<String> caps = <String>[];
    final dynamic rawCaps = json['capabilities'];
    if (rawCaps is List) {
      for (final dynamic c in rawCaps) {
        caps.add(c.toString());
      }
    }
    return SyncProviderInfo(
      key: asString(json['key']) ?? '',
      name: asString(json['name']) ?? asString(json['key']) ?? '',
      description: asString(json['description']),
      available: available,
      status: status,
      capabilities: caps,
    );
  }
}

/// 平台连接（/sync/connections）
class SyncConnection {
  final String id;
  final String provider;
  final String status;
  final String? externalUserId;
  final int? lastSyncAt;
  final String? lastError;

  const SyncConnection({
    required this.id,
    required this.provider,
    this.status = 'connected',
    this.externalUserId,
    this.lastSyncAt,
    this.lastError,
  });

  factory SyncConnection.fromJson(Map<String, dynamic> json) {
    return SyncConnection(
      id: asString(json['id']) ?? '',
      provider: asString(json['provider']) ?? '',
      status: asString(json['status']) ?? 'connected',
      externalUserId: asString(json['externalUserId']),
      lastSyncAt: asEpochMs(json['lastSyncAt']),
      lastError: asString(json['lastError']),
    );
  }
}

/// 同步任务审计（/sync/jobs）
class SyncJob {
  final String id;
  final String? connectionId;
  final String? provider;
  final int? startedAt;
  final int? finishedAt;
  final String status;
  final int added;
  final int skipped;
  final String? errorMsg;

  const SyncJob({
    required this.id,
    this.connectionId,
    this.provider,
    this.startedAt,
    this.finishedAt,
    this.status = '',
    this.added = 0,
    this.skipped = 0,
    this.errorMsg,
  });

  factory SyncJob.fromJson(Map<String, dynamic> json) {
    return SyncJob(
      id: asString(json['id']) ?? '',
      connectionId: asString(json['connectionId']),
      provider: asString(json['provider']),
      startedAt: asEpochMs(json['startedAt']),
      finishedAt: asEpochMs(json['finishedAt']),
      status: asString(json['status']) ?? '',
      added: asInt(json['added']) ?? 0,
      skipped: asInt(json['skipped']) ?? 0,
      errorMsg: asString(json['errorMsg']),
    );
  }
}
