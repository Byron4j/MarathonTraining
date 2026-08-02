'use strict';
// 档案模块：个人档案 + 心率区间（docs/03 第 2 节）
const { errors } = require('../../lib/http');
const { hrZones, HR_ZONE_DEFS } = require('../plans/engine');
const { toCamelProfile } = require('../auth');

const FIELD_MAP = {
  nickname: 'nickname',
  gender: 'gender',
  birthDate: 'birth_date',
  heightCm: 'height_cm',
  weightKg: 'weight_kg',
  restingHr: 'resting_hr',
  maxHr: 'max_hr',
  pb5kSec: 'pb_5k_sec',
  pb10kSec: 'pb_10k_sec',
  pbHalfSec: 'pb_half_sec',
  pbFullSec: 'pb_full_sec',
  weeklyKm: 'weekly_km',
  yearsRunning: 'years_running',
};

function getProfile(db, userId) {
  return db.prepare('SELECT * FROM profiles WHERE user_id = ?').get(userId);
}

function register(router, { db }) {
  router.get('/profile', async (req, res, ctx) => {
    const row = getProfile(db, ctx.user.id);
    if (!row) throw errors.notFound('档案不存在');
    return { profile: toCamelProfile(row) };
  });

  // 全量更新档案字段；心率区间自动重算
  router.put('/profile', async (req, res, ctx) => {
    const body = ctx.body || {};
    const row = getProfile(db, ctx.user.id);
    if (!row) throw errors.notFound('档案不存在');

    const next = {};
    for (const [camel, col] of Object.entries(FIELD_MAP)) {
      next[col] = body[camel] !== undefined ? body[camel] : row[col];
    }
    if (next.gender != null && !['male', 'female', 'other'].includes(next.gender)) {
      throw errors.badRequest('gender 需为 male|female|other');
    }
    // 心率区间自动重算（缓存到 hr_zones_json）
    const zones = hrZones(next.resting_hr, next.max_hr);

    db.prepare(`UPDATE profiles SET nickname=?, gender=?, birth_date=?, height_cm=?, weight_kg=?,
        resting_hr=?, max_hr=?, pb_5k_sec=?, pb_10k_sec=?, pb_half_sec=?, pb_full_sec=?,
        weekly_km=?, years_running=?, hr_zones_json=? WHERE user_id=?`)
      .run(
        next.nickname, next.gender, next.birth_date, next.height_cm, next.weight_kg,
        next.resting_hr, next.max_hr, next.pb_5k_sec, next.pb_10k_sec, next.pb_half_sec, next.pb_full_sec,
        next.weekly_km, next.years_running, JSON.stringify(zones), ctx.user.id,
      );
    return { profile: toCamelProfile(getProfile(db, ctx.user.id)) };
  });

  router.get('/profile/zones', async (req, res, ctx) => {
    const row = getProfile(db, ctx.user.id);
    if (!row) throw errors.notFound('档案不存在');
    return {
      restingHr: row.resting_hr,
      maxHr: row.max_hr,
      method: 'karvonen',
      zoneDefs: HR_ZONE_DEFS,
      zones: hrZones(row.resting_hr, row.max_hr),
    };
  });
}

module.exports = { register, getProfile };
