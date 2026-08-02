import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/plan.dart';
import '../repositories/plan_repository.dart';
import '../services/plan_service.dart';

class PlanProvider extends ChangeNotifier {
  final PlanRepository _repo;
  final PlanService _service;

  List<TrainingPlan> plans = <TrainingPlan>[];
  bool loading = false;
  String? error;

  PlanDetail? detail;
  bool detailLoading = false;
  String? detailError;

  PlanPreview? preview;
  bool previewLoading = false;
  String? previewError;

  PlanProvider(this._repo, this._service);

  Future<void> loadPlans() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      plans = await _repo.list();
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  TrainingPlan? get activePlan {
    for (final TrainingPlan p in plans) {
      if (p.status == 'active') return p;
    }
    return plans.isEmpty ? null : plans.first;
  }

  Future<void> loadDetail(String planId) async {
    detailLoading = true;
    detailError = null;
    notifyListeners();
    try {
      detail = await _repo.detail(planId);
    } catch (e) {
      detailError = apiErrorMessage(e);
    } finally {
      detailLoading = false;
      notifyListeners();
    }
  }

  Future<PlanPreview?> runPreview(PlanParams params) async {
    previewLoading = true;
    previewError = null;
    preview = null;
    notifyListeners();
    try {
      preview = await _service.preview(params);
      return preview;
    } catch (e) {
      previewError = apiErrorMessage(e);
      return null;
    } finally {
      previewLoading = false;
      notifyListeners();
    }
  }

  Future<TrainingPlan?> createPlan(PlanParams params) async {
    try {
      final TrainingPlan created = await _service.create(params);
      plans = <TrainingPlan>[created, ...plans];
      notifyListeners();
      return created;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> markWorkout(
    String planId,
    String workoutId,
    String status,
  ) async {
    try {
      await _repo.markWorkoutStatus(planId, workoutId, status);
      final PlanDetail? d = detail;
      if (d != null && d.plan.id == planId) {
        final List<PlanWorkout> updated = d.workouts
            .map((w) => w.id == workoutId ? w.copyWith(status: status) : w)
            .toList();
        detail = PlanDetail(plan: d.plan, workouts: updated);
        notifyListeners();
      }
      return true;
    } catch (e) {
      detailError = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// 自适应调整；返回展示用文本
  Future<String> adapt(String planId) async {
    try {
      final Map<String, dynamic> result = await _repo.adapt(planId);
      // 重算后续课表后刷新详情
      await loadDetail(planId);
      final dynamic suggestions = result['suggestions'] ?? result['message'];
      if (suggestions is List && suggestions.isNotEmpty) {
        return suggestions.map((e) => e.toString()).join('\n');
      }
      if (suggestions != null) return suggestions.toString();
      return '已根据近 2 周完成度重新评估计划。';
    } catch (e) {
      return '调整失败：${apiErrorMessage(e)}';
    }
  }

  Future<bool> archive(String planId) async {
    try {
      await _repo.archive(planId);
      plans = plans.where((p) => p.id != planId).toList();
      if (detail?.plan.id == planId) detail = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }
}
