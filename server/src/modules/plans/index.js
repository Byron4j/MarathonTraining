'use strict';
// 训练计划模块：options/preview/CRUD/workout status/adapt（docs/03 第 5 节）
const { errors } = require('../../lib/http');
const { uuid } = require('../auth');
const engine = require('./engine');
const { getProfile } = require('../profile');

function buildInput(db, userId, body) {
  const profile = getProfile(db, userId) || {};
  return {
    raceType: body.raceType,
    goalTimeSec: body.goalTimeSec != null ? Number(body.goalTimeSec) : null,
    weeks: body.weeks != null ? Number(body.weeks) : null,
    raceDate: body.raceDate || null,
    sessionsPerWeek: Number(body.sessionsPerWeek),
    vdot: body.vdot != null ? Number(body.vdot) : null,
    startDate: body.startDate || null,
    weeklyKm: body.weeklyKm != null ? Number(body.weeklyKm) : profile.weekly_km,
    pbs: {
      pb5kSec: body.pb5kSec ?? profile.pb_5k_sec,
      pb10kSec: body.pb10kSec ?? profile.pb_10k_sec,
      pbHalfSec: body.pbHalfSec ?? profile.pb_half_sec,
      pbFullSec: body.pbFullSec ?? profile.pb_full_sec,
    },
  };
}

function validateBody(body) {
  if (!body || !body.raceType) throw errors.badRequest('raceType 必填（5k|10k|half|full）');
  if (!body.sessionsPerWeek) throw errors.badRequest('sessionsPerWeek 必填（3–6）');
  if (body.weeks == null && !body.raceDate) throw errors.badRequest('weeks 与 raceDate 需二选一');
}

function workoutToCamel(w) {
  return {
    id: w.id,
    date: w.date,
    weekNo: w.week_no ?? w.weekNo,
    dayOfWeek: w.day_of_week ?? w.dayOfWeek,
    orderInDay: w.order_in_day ?? 1,
    workoutType: w.workout_type ?? w.workoutType,
    title: w.title,
    description: w.description,
    targetDistanceM: w.target_distance_m ?? w.targetDistanceM,
    targetDurationSec: w.target_duration_sec ?? w.targetDurationSec,
    paceMinSec: w.pace_min_sec ?? w.paceMinSec,
    paceMaxSec: w.pace_max_sec ?? w.paceMaxSec,
    hrZone: w.hr_zone ?? w.hrZone,
    status: w.status || 'pending',
    activityId: w.activity_id ?? null,
  };
}

function planToCamel(row) {
  return {
    id: row.id,
    name: row.name,
    raceType: row.race_type,
    goalTimeSec: row.goal_time_sec,
    raceDate: row.race_date,
    startDate: row.start_date,
    weeks: row.weeks,
    sessionsPerWeek: row.sessions_per_week,
    vdot: row.vdot,
    status: row.status,
    params: row.params_json ? JSON.parse(row.params_json) : null,
    createdAt: row.created_at,
  };
}

function register(router, { db }) {
  // 目标类型、课型、默认参数说明
  router.get('/plans/options', async () => ({
    raceTypes: Object.entries(engine.RACE_NAMES).map(([key, name]) => ({
      key, name, distanceM: engine.RACE_DISTANCE_M[key],
      defaultWeeks: { '5k': 8, '10k': 10, half: 12, full: 18 }[key],
    })),
    workoutTypes: ['E', 'M', 'T', 'I', 'R', 'L', 'RECOVERY', 'XT', 'REST', 'RACE'],
    sessionsPerWeek: { min: 3, max: 6, note: '7 练不建议' },
    defaults: {
      weeks: 18, sessionsPerWeek: 4, startDate: '下周一',
      taperWeeks: { '5k': 1, '10k': 2, half: 2, full: 3 },
      volumeRule: '起始量=max(当前周跑量, 距离下限)，每周 +5~8%，每 4 周减量 −25%，峰值按距离封顶并随 VDOT 缩放',
    },
    params: {
      raceType: '5k|10k|half|full', goalTimeSec: '可空=完赛目标',
      weeks: '与 raceDate 二选一', sessionsPerWeek: '3–6',
      vdot: '可空 → 由 PB/近期数据推断', startDate: '可空 → 下周一',
    },
  }));

  // 参数试算：返回 VDOT、配速区、周概览（不落库）
  router.post('/plans/preview', async (req, res, ctx) => {
    validateBody(ctx.body);
    let plan;
    try {
      plan = engine.generatePlan(buildInput(db, ctx.user.id, ctx.body));
    } catch (err) {
      throw errors.badRequest(err.message);
    }
    return {
      vdot: plan.vdot,
      vdotSource: plan.vdotSource,
      goalVdot: plan.goalVdot,
      raceDate: plan.raceDate,
      startDate: plan.startDate,
      weeks: plan.weeks,
      paces: plan.paces,
      warnings: plan.warnings,
      weekOverview: plan.weekCurve,
      sampleWorkouts: plan.workouts.slice(0, plan.sessionsPerWeek).map(workoutToCamel),
    };
  });

  // 生成并保存计划
  router.post('/plans', async (req, res, ctx) => {
    validateBody(ctx.body);
    let plan;
    try {
      plan = engine.generatePlan(buildInput(db, ctx.user.id, ctx.body));
    } catch (err) {
      throw errors.badRequest(err.message);
    }
    const id = uuid();
    const name = (ctx.body.name || `${plan.raceName} ${plan.weeks} 周计划`).trim();
    db.exec('BEGIN');
    try {
      db.prepare(`INSERT INTO training_plans
        (id, user_id, name, race_type, goal_time_sec, race_date, start_date, weeks,
         sessions_per_week, vdot, status, params_json, created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?, 'active', ?, ?)`)
        .run(id, ctx.user.id, name, plan.raceType, plan.goalTimeSec, plan.raceDate, plan.startDate,
          plan.weeks, plan.sessionsPerWeek, plan.vdot, JSON.stringify({ ...ctx.body, warnings: plan.warnings }), Date.now());
      const stmt = db.prepare(`INSERT INTO plan_workouts
        (id, plan_id, date, week_no, day_of_week, order_in_day, workout_type, title, description,
         target_distance_m, target_duration_sec, pace_min_sec, pace_max_sec, hr_zone, status)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'pending')`);
      for (const w of plan.workouts) {
        stmt.run(uuid(), id, w.date, w.weekNo, w.dayOfWeek, w.orderInDay, w.workoutType, w.title,
          w.description, w.targetDistanceM, w.targetDurationSec, w.paceMinSec, w.paceMaxSec, w.hrZone);
      }
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
    const row = db.prepare('SELECT * FROM training_plans WHERE id = ?').get(id);
    return { plan: { ...planToCamel(row), warnings: plan.warnings, weekOverview: plan.weekCurve } };
  });

  router.get('/plans', async (req, res, ctx) => {
    const rows = db.prepare(`SELECT * FROM training_plans WHERE user_id = ? AND status != 'archived'
      ORDER BY created_at DESC`).all(ctx.user.id);
    return { plans: rows.map(planToCamel) };
  });

  // 计划详情（含全部课表）
  router.get('/plans/:id', async (req, res, ctx) => {
    const row = db.prepare('SELECT * FROM training_plans WHERE id = ? AND user_id = ?')
      .get(ctx.params.id, ctx.user.id);
    if (!row) throw errors.notFound('计划不存在');
    const workouts = db.prepare(`SELECT * FROM plan_workouts WHERE plan_id = ?
      ORDER BY week_no, day_of_week, order_in_day`).all(row.id);
    return { plan: planToCamel(row), workouts: workouts.map(workoutToCamel) };
  });

  // 标记 done/skipped，可关联 activityId
  router.post('/plans/:id/workouts/:workoutId/status', async (req, res, ctx) => {
    const { status, activityId } = ctx.body || {};
    if (!['done', 'skipped', 'missed', 'pending'].includes(status)) {
      throw errors.badRequest('status 需为 done|skipped|missed|pending');
    }
    const plan = db.prepare('SELECT * FROM training_plans WHERE id = ? AND user_id = ?')
      .get(ctx.params.id, ctx.user.id);
    if (!plan) throw errors.notFound('计划不存在');
    if (activityId) {
      const act = db.prepare('SELECT id FROM activities WHERE id = ? AND user_id = ?')
        .get(activityId, ctx.user.id);
      if (!act) throw errors.badRequest('关联的活动不存在');
    }
    const r = db.prepare('UPDATE plan_workouts SET status = ?, activity_id = COALESCE(?, activity_id) WHERE id = ? AND plan_id = ?')
      .run(status, activityId || null, ctx.params.workoutId, plan.id);
    if (r.changes === 0) throw errors.notFound('课表不存在');
    const w = db.prepare('SELECT * FROM plan_workouts WHERE id = ?').get(ctx.params.workoutId);
    return { workout: workoutToCamel(w) };
  });

  // 基于近 2 周完成度给出调整建议/重算后续（docs/04 第 7 节）
  router.post('/plans/:id/adapt', async (req, res, ctx) => {
    const plan = db.prepare('SELECT * FROM training_plans WHERE id = ? AND user_id = ?')
      .get(ctx.params.id, ctx.user.id);
    if (!plan) throw errors.notFound('计划不存在');

    const today = new Date().toISOString().slice(0, 10);
    const twoWeeksAgo = new Date(Date.now() - 14 * 86400000).toISOString().slice(0, 10);
    const recent = db.prepare(`SELECT status FROM plan_workouts
      WHERE plan_id = ? AND date >= ? AND date <= ? AND workout_type != 'REST'`)
      .all(plan.id, twoWeeksAgo, today);
    const done = recent.filter((r) => r.status === 'done').length;
    const missed = recent.filter((r) => r.status === 'missed' || r.status === 'skipped').length;

    // 新 PB 检测：档案 PB 对应 VDOT 高于计划快照 VDOT
    const profile = getProfile(db, ctx.user.id) || {};
    const pbVdot = engine.vdotFromPbs({
      pb5kSec: profile.pb_5k_sec, pb10kSec: profile.pb_10k_sec,
      pbHalfSec: profile.pb_half_sec, pbFullSec: profile.pb_full_sec,
    });
    const hasNewPb = pbVdot !== null && plan.vdot !== null && pbVdot - plan.vdot >= 1;

    const suggestion = engine.adaptSuggestion(done, missed, hasNewPb);

    // 重算后续：未来 pending 课表按 volumeFactor 调整量；降强度时 I→T
    const future = db.prepare(`SELECT * FROM plan_workouts WHERE plan_id = ? AND date > ? AND status = 'pending'`)
      .all(plan.id, today);
    let adjusted = 0;
    if (suggestion.action !== 'maintain') {
      const upd = db.prepare(`UPDATE plan_workouts SET target_distance_m = ?, target_duration_sec = ?,
        workout_type = ?, title = ? WHERE id = ?`);
      for (const w of future) {
        let type = w.workout_type;
        let title = w.title;
        if (suggestion.action === 'reduce_intensity' && type === 'I') { type = 'T'; title = title.replace('间歇', '节奏'); }
        const newDist = w.target_distance_m ? Math.round(w.target_distance_m * suggestion.volumeFactor) : null;
        const newDur = w.target_duration_sec ? Math.round(w.target_duration_sec * suggestion.volumeFactor) : null;
        upd.run(newDist, newDur, type, title, w.id);
        adjusted += 1;
      }
    }
    return {
      suggestion,
      window: { from: twoWeeksAgo, to: today, done, missed },
      adjustedFutureWorkouts: adjusted,
    };
  });

  // 归档
  router.delete('/plans/:id', async (req, res, ctx) => {
    const r = db.prepare(`UPDATE training_plans SET status = 'archived' WHERE id = ? AND user_id = ?`)
      .run(ctx.params.id, ctx.user.id);
    if (r.changes === 0) throw errors.notFound('计划不存在');
    return { ok: true, status: 'archived' };
  });
}

module.exports = { register };
