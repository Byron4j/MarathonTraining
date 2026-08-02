'use strict';
// 活动模块：列表/详情/手动录入/删除/GPX 导入（docs/03 第 3 节）
const { errors } = require('../../lib/http');
const { uuid } = require('../auth');
const { parseGpx } = require('./gpx');

function toCamel(row) {
  return {
    id: row.id,
    provider: row.provider,
    sport: row.sport,
    startTime: row.start_time,
    durationSec: row.duration_sec,
    distanceM: row.distance_m,
    elevationGainM: row.elevation_gain_m,
    avgPaceSecPerKm: row.avg_pace_sec_per_km,
    avgHr: row.avg_hr,
    maxHr: row.max_hr,
    avgCadence: row.avg_cadence,
    calories: row.calories,
    trainingEffect: row.training_effect,
    sourceFile: row.source_file,
    createdAt: row.created_at,
  };
}

function insertActivity(db, userId, a) {
  const id = a.id || uuid();
  db.prepare(`INSERT INTO activities
    (id, user_id, provider, external_id, sport, start_time, duration_sec, distance_m,
     elevation_gain_m, avg_pace_sec_per_km, avg_hr, max_hr, avg_cadence, calories,
     training_effect, source_file, raw_json, created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(
      id, userId, a.provider || 'manual', a.externalId || null, a.sport || 'run',
      a.startTime, a.durationSec, a.distanceM, a.elevationGainM ?? null,
      a.avgPaceSecPerKm ?? (a.distanceM > 0 ? Math.round(a.durationSec / (a.distanceM / 1000)) : null),
      a.avgHr ?? null, a.maxHr ?? null, a.avgCadence ?? null, a.calories ?? null,
      a.trainingEffect ?? null, a.sourceFile ?? null, a.rawJson ?? null, Date.now(),
    );
  return id;
}

function register(router, { db }) {
  // 分页列表（时间倒序）
  router.get('/activities', async (req, res, ctx) => {
    const page = Math.max(1, Number(ctx.query.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(ctx.query.pageSize) || 20));
    const conds = ['user_id = ?'];
    const args = [ctx.user.id];
    if (ctx.query.from) { conds.push('start_time >= ?'); args.push(Number(ctx.query.from)); }
    if (ctx.query.to) { conds.push('start_time <= ?'); args.push(Number(ctx.query.to)); }
    const where = conds.join(' AND ');
    const total = db.prepare(`SELECT COUNT(*) c FROM activities WHERE ${where}`).get(...args).c;
    const rows = db.prepare(`SELECT * FROM activities WHERE ${where}
      ORDER BY start_time DESC LIMIT ? OFFSET ?`).all(...args, pageSize, (page - 1) * pageSize);
    return { items: rows.map(toCamel), page, pageSize, total };
  });

  // 详情（含 laps/streams）
  router.get('/activities/:id', async (req, res, ctx) => {
    const row = db.prepare('SELECT * FROM activities WHERE id = ? AND user_id = ?')
      .get(ctx.params.id, ctx.user.id);
    if (!row) throw errors.notFound('活动不存在');
    const laps = db.prepare('SELECT * FROM activity_laps WHERE activity_id = ? ORDER BY lap_no').all(row.id)
      .map((l) => ({
        lapNo: l.lap_no, distanceM: l.distance_m, durationSec: l.duration_sec,
        avgHr: l.avg_hr, avgPace: l.avg_pace,
      }));
    const s = db.prepare('SELECT * FROM activity_streams WHERE activity_id = ?').get(row.id);
    const streams = s ? {
      sampleSec: s.sample_sec,
      hr: s.hr_json ? JSON.parse(s.hr_json) : [],
      pace: s.pace_json ? JSON.parse(s.pace_json) : [],
      cadence: s.cadence_json ? JSON.parse(s.cadence_json) : [],
      alt: s.alt_json ? JSON.parse(s.alt_json) : [],
    } : null;
    return { activity: { ...toCamel(row), laps, streams } };
  });

  // 手动录入
  router.post('/activities', async (req, res, ctx) => {
    const b = ctx.body || {};
    if (!b.startTime || !b.durationSec || !b.distanceM) {
      throw errors.badRequest('startTime / durationSec / distanceM 必填');
    }
    if (Number(b.durationSec) <= 0 || Number(b.distanceM) <= 0) {
      throw errors.badRequest('durationSec / distanceM 必须为正数');
    }
    const id = insertActivity(db, ctx.user.id, {
      provider: 'manual',
      sport: b.sport || 'run',
      startTime: Number(b.startTime),
      durationSec: Number(b.durationSec),
      distanceM: Number(b.distanceM),
      elevationGainM: b.elevationGainM,
      avgHr: b.avgHr, maxHr: b.maxHr, avgCadence: b.avgCadence, calories: b.calories,
    });
    const row = db.prepare('SELECT * FROM activities WHERE id = ?').get(id);
    return { activity: toCamel(row) };
  });

  router.delete('/activities/:id', async (req, res, ctx) => {
    const r = db.prepare('DELETE FROM activities WHERE id = ? AND user_id = ?')
      .run(ctx.params.id, ctx.user.id);
    if (r.changes === 0) throw errors.notFound('活动不存在');
    return { ok: true };
  });

  // 文件导入：{filename, contentBase64}（GPX），指纹去重
  router.post('/activities/import', async (req, res, ctx) => {
    const { filename, contentBase64 } = ctx.body || {};
    if (!filename || !contentBase64) throw errors.badRequest('filename / contentBase64 必填');
    if (!/\.gpx$/i.test(filename)) throw errors.badRequest('目前仅支持 GPX 文件（FIT/TCX 下一迭代）');
    let xml;
    try {
      xml = Buffer.from(String(contentBase64), 'base64').toString('utf8');
    } catch {
      throw errors.badRequest('contentBase64 解码失败');
    }
    let parsed;
    try {
      parsed = parseGpx(xml, filename);
    } catch (err) {
      throw errors.badRequest(`GPX 解析失败: ${err.message}`);
    }
    const dup = db.prepare('SELECT id FROM activities WHERE user_id = ? AND provider = ? AND external_id = ?')
      .get(ctx.user.id, parsed.provider, parsed.externalId);
    if (dup) return { activity: { id: dup.id }, duplicated: true };
    const id = insertActivity(db, ctx.user.id, parsed);
    const row = db.prepare('SELECT * FROM activities WHERE id = ?').get(id);
    return { activity: toCamel(row), duplicated: false };
  });
}

module.exports = { register, insertActivity, toCamel };
