import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';

class ActivitiesProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final ActivityRepository _repo;

  List<Activity> items = <Activity>[];
  int page = 1;
  int total = 0;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  ActivitiesProvider(this._repo);

  bool get hasMore => items.length < total;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final PagedActivities result =
          await _repo.list(page: 1, pageSize: pageSize);
      items = result.items;
      page = result.page;
      total = result.total;
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final PagedActivities result =
          await _repo.list(page: page + 1, pageSize: pageSize);
      items = <Activity>[...items, ...result.items];
      page = result.page;
      total = result.total;
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// 详情（含 laps/streams），不入缓存，由调用方持有
  Future<Activity> fetchDetail(String id) => _repo.detail(id);

  Future<Activity?> createManual(Map<String, dynamic> body) async {
    try {
      final Activity created = await _repo.create(body);
      items = <Activity>[created, ...items];
      total += 1;
      notifyListeners();
      return created;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteActivity(String id) async {
    try {
      await _repo.delete(id);
      items = items.where((a) => a.id != id).toList();
      total = total > 0 ? total - 1 : 0;
      notifyListeners();
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<ActivityImportResult?> importFile(
    String filename,
    String contentBase64,
  ) async {
    try {
      final ActivityImportResult result =
          await _repo.importFile(filename, contentBase64);
      await refresh();
      return result;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return null;
    }
  }
}
