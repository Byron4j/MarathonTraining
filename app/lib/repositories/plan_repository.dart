import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/model_utils.dart';
import '../models/plan.dart';

/// 训练计划接口（docs/03 第 5 节）
class PlanRepository {
  final ApiClient _api;

  PlanRepository(this._api);

  Future<PlanPreview> preview(PlanParams params) async {
    final Response<dynamic> res =
        await _api.dio.post('/plans/preview', data: params.toJson());
    return PlanPreview.fromJson(asMap(res.data));
  }

  Future<TrainingPlan> create(PlanParams params) async {
    final Response<dynamic> res = await _api.dio.post(
      '/plans',
      data: params.toJson(includeName: true),
    );
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> planJson =
        data['plan'] is Map ? asMap(data['plan']) : data;
    return TrainingPlan.fromJson(planJson);
  }

  Future<List<TrainingPlan>> list() async {
    final Response<dynamic> res = await _api.dio.get('/plans');
    final dynamic data = res.data;
    if (data is List) return asMapList(data).map(TrainingPlan.fromJson).toList();
    final Map<String, dynamic> map = asMap(data);
    final dynamic items = map['items'] ?? map['plans'];
    return asMapList(items).map(TrainingPlan.fromJson).toList();
  }

  Future<PlanDetail> detail(String id) async {
    final Response<dynamic> res = await _api.dio.get('/plans/$id');
    final Map<String, dynamic> data = asMap(res.data);
    final Map<String, dynamic> planJson =
        data['plan'] is Map ? asMap(data['plan']) : data;
    final dynamic workoutsRaw = data['workouts'] ?? planJson['workouts'];
    return PlanDetail(
      plan: TrainingPlan.fromJson(planJson),
      workouts: asMapList(workoutsRaw).map(PlanWorkout.fromJson).toList(),
    );
  }

  Future<void> markWorkoutStatus(
    String planId,
    String workoutId,
    String status, {
    String? activityId,
  }) async {
    await _api.dio.post(
      '/plans/$planId/workouts/$workoutId/status',
      data: <String, dynamic>{
        'status': status,
        if (activityId != null) 'activityId': activityId,
      },
    );
  }

  /// 自适应调整：返回建议/重算结果原文
  Future<Map<String, dynamic>> adapt(String planId) async {
    final Response<dynamic> res = await _api.dio.post('/plans/$planId/adapt');
    return asMap(res.data);
  }

  Future<void> archive(String id) async {
    await _api.dio.delete('/plans/$id');
  }
}
