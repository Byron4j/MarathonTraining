import '../models/plan.dart';
import '../repositories/plan_repository.dart';

/// 计划编排：向导试算（preview）与生成。
class PlanService {
  final PlanRepository _repo;

  PlanService(this._repo);

  /// 参数试算：VDOT、配速区、周概览（不落库）
  Future<PlanPreview> preview(PlanParams params) => _repo.preview(params);

  /// 生成并保存计划
  Future<TrainingPlan> create(PlanParams params) => _repo.create(params);
}
