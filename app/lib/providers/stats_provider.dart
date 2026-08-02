import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/stats.dart';
import '../repositories/stats_repository.dart';

class StatsProvider extends ChangeNotifier {
  final StatsRepository _repo;

  Dashboard? dashboard;
  List<WeeklyStat> weekly = <WeeklyStat>[];
  bool loading = false;
  String? error;

  StatsProvider(this._repo);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      dashboard = await _repo.dashboard();
      try {
        weekly = await _repo.weekly(weeks: 12);
      } catch (_) {
        weekly = <WeeklyStat>[];
      }
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
