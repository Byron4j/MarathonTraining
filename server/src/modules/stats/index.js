'use strict';
// 统计模块：仪表盘、周跑量、心率区间分布、ATL/CTL/TSB（docs/03 第 6 节、docs/04 第 8 节）
const { hrZones } = require('../plans/engine');
const { getProfile } = require('../profile');

// TRIMP ≈ duration(min) × HR储备比 × 性别系数（Banister 简化）
function trimp(a, restingHr, maxHr, gender) {
  if (!a.avg_hr || !restingHr || !maxHr || maxHr <= restingHr) {
    return a.duration_sec / 60 * 0.5; // 无心率时按低强度估计
  }
  const ratio = Math.max(0, Math.min(1, (a.avg_hr - restingHr) / (maxHr - restingHr)));
  const k = gender === 'female' ? 1.67 : 1.92;
  return (a.duration_sec / 60) * ratio * 0.64 * Math.exp(k * ratio);
}

// ATL = 近 7 天 TRIMP 指数加权；CTL = 近 42 天指数加权；TSB = CTL − ATL
function fitnessLoad(activities, restingHr, maxHr, gender, days = 60) {
  const now = Date.now();
  const dayMs = 86400000;
  const daily = new Map();
  for (const a of activities) {
    const dayIdx = Math.floor((now - a.start_time) / dayMs);
    if (dayIdx < 0 || dayIdx >= days) continue;
    daily.set(dayIdx, (daily.get(dayIdx) || 0) + trimp(a, restingHr, maxHr, gender));
  }
  let atl = 0;
  let ctl = 0;
  // 从远到近做指数加权
  for (let d = days - 1; d >= 0; d -= 1) {
    const t = daily.get(d) || 0;
    atl += (t - atl) / 7;
    ctl += (t - ctl) / 42;
  }
  const r1 = (x) => Math.round(x * 10) / 10;
  return { atl: r1(atl), ctl: r1(ctl), tsb: r1(ctl - atl) };
}

function mondayOfWeek(ts) {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  const dow = d.getDay() || 7;
  d.setDate(d.getDate() - (dow - 1));
  return d.getTime();
}

function register(router, { db }) {
  // 本周跑量、计划完成度、ATL/CTL/TSB、最近活动
  router.get('/stats/dashboard', async (req, res, ctx) => {
    const userId = ctx.user.id;
    const profile = getProfile(db, userId) || {};
    const all = db.prepare('SELECT * FROM activities WHERE user_id = ? ORDER BY start_time DESC').all(userId);

    const weekStart = mondayOfWeek(Date.now());
    const thisWeek = all.filter((a) => a.start_time >= weekStart);
    const weekDistanceM = thisWeek.reduce((s, a) => s + a.distance_m, 0);

    const plan = db.prepare(`SELECT * FROM training_plans WHERE user_id = ? AND status = 'active'
      ORDER BY created_at DESC LIMIT 1`).get(userId);
    let planProgress = null;
    if (plan) {
      const today = new Date().toISOString().slice(0, 10);
      const rows = db.prepare(`SELECT status, COUNT(*) c FROM plan_workouts
        WHERE plan_id = ? AND date <= ? AND workout_type != 'REST' GROUP BY status`).all(plan.id, today);
      const done = rows.find((r) => r.status === 'done')?.c || 0;
      const total = rows.reduce((s, r) => s + r.c, 0);
      planProgress = {
        planId: plan.id, name: plan.name, done, total,
        completionRate: total ? Math.round((done / total) * 100) / 100 : null,
      };
    }

    const load = fitnessLoad(all, profile.resting_hr, profile.max_hr, profile.gender);

    return {
      weekDistanceM: Math.round(weekDistanceM),
      weekCount: thisWeek.length,
      totalActivities: all.length,
      atl: load.atl, ctl: load.ctl, tsb: load.tsb,
      planProgress,
      recentActivities: all.slice(0, 5).map((a) => ({
        id: a.id, provider: a.provider, sport: a.sport, startTime: a.start_time,
        distanceM: a.distance_m, durationSec: a.duration_sec,
        avgPaceSecPerKm: a.avg_pace_sec_per_km, avgHr: a.avg_hr,
      })),
    };
  });

  // 周跑量/次数/均配速
  router.get('/stats/weekly', async (req, res, ctx) => {
    const weeks = Math.min(52, Math.max(1, Number(ctx.query.weeks) || 12));
    const since = mondayOfWeek(Date.now()) - (weeks - 1) * 7 * 86400000;
    const rows = db.prepare(`SELECT * FROM activities WHERE user_id = ? AND start_time >= ?
      ORDER BY start_time`).all(ctx.user.id, since);
    const buckets = new Map();
    for (let w = weeks - 1; w >= 0; w -= 1) {
      const start = mondayOfWeek(Date.now()) - w * 7 * 86400000;
      buckets.set(start, { weekStart: start, distanceM: 0, count: 0, durationSec: 0 });
    }
    for (const a of rows) {
      const key = mondayOfWeek(a.start_time);
      const b = buckets.get(key);
      if (!b) continue;
      b.distanceM += a.distance_m;
      b.count += 1;
      b.durationSec += a.duration_sec;
    }
    return {
      weeks: [...buckets.values()].map((b) => ({
        weekStart: b.weekStart,
        distanceM: Math.round(b.distanceM),
        count: b.count,
        avgPaceSecPerKm: b.distanceM > 0 ? Math.round(b.durationSec / (b.distanceM / 1000)) : null,
      })),
    };
  });

  // 心率区间时间分布（按 avg_hr 归属区间聚合时长；有 streams 时按样本）
  router.get('/stats/hr-distribution', async (req, res, ctx) => {
    const userId = ctx.user.id;
    const profile = getProfile(db, userId) || {};
    const zones = hrZones(profile.resting_hr, profile.max_hr);
    const conds = ['user_id = ?', 'avg_hr IS NOT NULL'];
    const args = [userId];
    if (ctx.query.from) { conds.push('start_time >= ?'); args.push(Number(ctx.query.from)); }
    if (ctx.query.to) { conds.push('start_time <= ?'); args.push(Number(ctx.query.to)); }
    const rows = db.prepare(`SELECT * FROM activities WHERE ${conds.join(' AND ')}`).all(...args);

    const seconds = [0, 0, 0, 0, 0];
    for (const a of rows) {
      let idx = zones.findIndex((z) => a.avg_hr >= z.hrLo && a.avg_hr <= z.hrHi);
      if (idx === -1) idx = a.avg_hr < zones[0].hrLo ? 0 : 4;
      seconds[idx] += a.duration_sec;
    }
    const total = seconds.reduce((s, x) => s + x, 0);
    return {
      from: ctx.query.from ? Number(ctx.query.from) : null,
      to: ctx.query.to ? Number(ctx.query.to) : null,
      totalSec: total,
      zones: zones.map((z, i) => ({
        zone: z.zone, name: z.name, hrLo: z.hrLo, hrHi: z.hrHi,
        seconds: seconds[i],
        pct: total ? Math.round((seconds[i] / total) * 1000) / 10 : 0,
      })),
    };
  });
}

module.exports = { register, trimp, fitnessLoad };
