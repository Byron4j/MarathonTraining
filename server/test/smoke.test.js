'use strict';
// 端到端冒烟测试（node:test）：随机端口 + 独立临时 DB
// 运行：node --test server/test/
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { createServer } = require('../src/index.js');

let server;
let db;
let tmpDir;
let base;
let accessToken;
let refreshToken;
let headers;

async function api(method, p, body, token) {
  const resp = await fetch(`${base}${p}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let json = null;
  const text = await resp.text();
  try { json = text ? JSON.parse(text) : null; } catch { /* ignore */ }
  return { status: resp.status, body: json };
}

const GPX_SAMPLE = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="smoke-test">
 <trk><name>Morning Run</name><trkseg>
  <trkpt lat="31.2304" lon="121.4737"><ele>10</ele><time>2026-07-25T01:00:00Z</time><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>140</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt>
  <trkpt lat="31.2313" lon="121.4746"><ele>12</ele><time>2026-07-25T01:01:00Z</time><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>145</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt>
  <trkpt lat="31.2322" lon="121.4755"><ele>15</ele><time>2026-07-25T01:02:00Z</time><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>150</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt>
  <trkpt lat="31.2331" lon="121.4764"><ele>11</ele><time>2026-07-25T01:03:00Z</time><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>152</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt>
 </trkseg></trk>
</gpx>`;

before(async () => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'marathon-test-'));
  ({ server, db } = createServer({ dbPath: path.join(tmpDir, 'test.db'), port: 0 }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
});

after(() => {
  server.close();
  db.close();
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

test('健康检查 /health', async () => {
  const r = await api('GET', '/health');
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'ok');
  assert.ok(r.body.version);
});

test('未认证访问受保护端点 → 401', async () => {
  const r = await api('GET', '/activities');
  assert.equal(r.status, 401);
  assert.equal(r.body.error.code, 'UNAUTHORIZED');
});

test('注册 → 登录 → me', async () => {
  let r = await api('POST', '/auth/register', { email: 'Runner@Test.com', password: 'password123', nickname: '测试跑者' });
  assert.equal(r.status, 200);
  assert.equal(r.body.user.email, 'runner@test.com'); // 小写化
  assert.ok(r.body.tokens.accessToken && r.body.tokens.refreshToken);

  // 重复注册 → 409
  r = await api('POST', '/auth/register', { email: 'runner@test.com', password: 'password123' });
  assert.equal(r.status, 409);
  assert.equal(r.body.error.code, 'CONFLICT');

  // 错误密码 → 401
  r = await api('POST', '/auth/login', { email: 'runner@test.com', password: 'wrong-password' });
  assert.equal(r.status, 401);

  r = await api('POST', '/auth/login', { email: 'runner@test.com', password: 'password123' });
  assert.equal(r.status, 200);
  accessToken = r.body.tokens.accessToken;
  refreshToken = r.body.tokens.refreshToken;
  headers = accessToken;

  r = await api('GET', '/auth/me', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.user.email, 'runner@test.com');
  assert.ok(r.body.profile);
});

test('刷新令牌（旋转）', async () => {
  const r = await api('POST', '/auth/refresh', { refreshToken });
  assert.equal(r.status, 200);
  assert.ok(r.body.tokens.accessToken);
  // 旧 refresh token 已旋转失效
  const r2 = await api('POST', '/auth/refresh', { refreshToken });
  assert.equal(r2.status, 401);
  refreshToken = r.body.tokens.refreshToken;
  accessToken = r.body.tokens.accessToken;
});

test('更新档案 → 心率区间自动重算', async () => {
  let r = await api('PUT', '/profile', {
    nickname: '测试跑者', gender: 'male', restingHr: 55, maxHr: 185,
    weeklyKm: 40, pb10kSec: 2400, yearsRunning: 3, heightCm: 175, weightKg: 68,
  }, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.profile.restingHr, 55);

  r = await api('GET', '/profile/zones', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.method, 'karvonen');
  assert.equal(r.body.zones.length, 5);
  // Karvonen: Z2 = 55 + 130*[0.6, 0.7] = [133, 146]
  assert.equal(r.body.zones[1].hrLo, 133);
  assert.equal(r.body.zones[1].hrHi, 146);
});

test('Provider 列表：mock 可用，coros 无凭据 unavailable 不崩溃', async () => {
  const r = await api('GET', '/sync/providers', undefined, accessToken);
  assert.equal(r.status, 200);
  const mock = r.body.providers.find((p) => p.key === 'mock');
  const coros = r.body.providers.find((p) => p.key === 'coros');
  assert.equal(mock.status, 'available');
  assert.equal(coros.status, 'unavailable');
  assert.ok(coros.reason);
  // coros 授权 URL 接口正常返回说明
  const r2 = await api('GET', '/sync/connections/coros/authorize-url', undefined, accessToken);
  assert.equal(r2.status, 200);
  assert.equal(r2.body.status, 'unavailable');
});

let connectionId;
test('建立 mock 连接 → 触发同步 → 同步历史', async () => {
  let r = await api('POST', '/sync/connections', { provider: 'mock' }, accessToken);
  assert.equal(r.status, 200);
  connectionId = r.body.connection.id;
  assert.equal(r.body.connection.status, 'connected');

  r = await api('POST', `/sync/connections/${connectionId}/sync`, undefined, accessToken);
  assert.equal(r.status, 200);
  assert.ok(r.body.jobId);
  assert.ok(r.body.added >= 20, `近 8 周应生成 ≥20 次活动，实际 ${r.body.added}`);

  // 二次同步：游标增量 → 全部去重跳过
  r = await api('POST', `/sync/connections/${connectionId}/sync`, undefined, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.added, 0);
  assert.ok(r.body.skipped > 0);

  r = await api('GET', '/sync/jobs?limit=5', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.ok(r.body.jobs.length >= 2);
  assert.equal(r.body.jobs[0].status, 'success');
});

let firstActivityId;
test('活动列表 / 详情', async () => {
  const r = await api('GET', '/activities?page=1&pageSize=10', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.ok(r.body.total >= 20);
  assert.equal(r.body.items.length, 10);
  // 时间倒序
  assert.ok(r.body.items[0].startTime >= r.body.items[1].startTime);
  firstActivityId = r.body.items[0].id;

  const d = await api('GET', `/activities/${firstActivityId}`, undefined, accessToken);
  assert.equal(d.status, 200);
  assert.equal(d.body.activity.id, firstActivityId);
  assert.ok(Array.isArray(d.body.activity.laps));
});

test('手动录入活动', async () => {
  const startTime = Date.now() - 86400000;
  const r = await api('POST', '/activities', {
    sport: 'run', startTime, durationSec: 1800, distanceM: 5000, avgHr: 150, maxHr: 168,
  }, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.activity.provider, 'manual');
  assert.equal(r.body.activity.avgPaceSecPerKm, 360);

  const bad = await api('POST', '/activities', { startTime }, accessToken);
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error.code, 'VALIDATION_ERROR');
});

test('GPX 导入（含指纹去重）', async () => {
  const payload = { filename: 'morning-run.gpx', contentBase64: Buffer.from(GPX_SAMPLE).toString('base64') };
  let r = await api('POST', '/activities/import', payload, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.duplicated, false);
  const a = r.body.activity;
  assert.equal(a.provider, 'file-gpx');
  assert.equal(a.startTime, Date.parse('2026-07-25T01:00:00Z'));
  assert.equal(a.durationSec, 180);
  assert.ok(a.distanceM > 200, `距离应 >200m，实际 ${a.distanceM}`);
  assert.equal(a.avgHr, 147); // (140+145+150+152)/4 四舍五入
  assert.equal(a.maxHr, 152);

  // 重复导入 → 指纹去重
  r = await api('POST', '/activities/import', payload, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.duplicated, true);
});

test('删除活动', async () => {
  const created = await api('POST', '/activities', {
    startTime: Date.now(), durationSec: 600, distanceM: 2000,
  }, accessToken);
  const id = created.body.activity.id;
  const r = await api('DELETE', `/activities/${id}`, undefined, accessToken);
  assert.equal(r.status, 200);
  const d = await api('GET', `/activities/${id}`, undefined, accessToken);
  assert.equal(d.status, 404);
});

test('plans options / preview（VDOT 由 PB 反推，配速单调）', async () => {
  let r = await api('GET', '/plans/options', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.ok(r.body.raceTypes.find((t) => t.key === 'full'));

  r = await api('POST', '/plans/preview', {
    raceType: 'full', goalTimeSec: 14400, weeks: 18, sessionsPerWeek: 4,
  }, accessToken);
  assert.equal(r.status, 200);
  // PB 10K 40:00 → VDOT ≈ 49.8
  assert.ok(r.body.vdot > 45 && r.body.vdot < 55, `vdot=${r.body.vdot}`);
  assert.equal(r.body.weeks, 18);
  assert.equal(r.body.weekOverview.length, 18);
  // 配速区间单调合理：T 快于 M 快于 E
  const p = r.body.paces;
  assert.ok(p.T.fast < p.M.fast, 'T 应快于 M');
  assert.ok(p.M.fast < p.E.fast, 'M 应快于 E');
  assert.ok(p.E.fast < p.E.slow, '区间内快 < 慢');
});

let planId;
let planDetail;
test('创建全马 18 周 4 练计划 → 详情校验', async () => {
  const r = await api('POST', '/plans', {
    name: '首马破四计划', raceType: 'full', goalTimeSec: 14400,
    weeks: 18, sessionsPerWeek: 4, startDate: '2026-08-10',
  }, accessToken);
  assert.equal(r.status, 200);
  planId = r.body.plan.id;
  assert.equal(r.body.plan.weeks, 18);
  assert.equal(r.body.plan.status, 'active');

  const d = await api('GET', `/plans/${planId}`, undefined, accessToken);
  assert.equal(d.status, 200);
  planDetail = d.body;
  const ws = d.body.workouts;
  // 总周数正确
  assert.equal(Math.max(...ws.map((w) => w.weekNo)), 18);
  // 每周 4 练
  for (let w = 1; w <= 18; w += 1) {
    assert.equal(ws.filter((x) => x.weekNo === w).length, 4, `第 ${w} 周应有 4 次课`);
  }
  // 最后一周含 RACE 课
  const race = ws.filter((w) => w.workoutType === 'RACE');
  assert.equal(race.length, 1);
  assert.equal(race[0].weekNo, 18);
  assert.equal(race[0].targetDistanceM, 42195);
  assert.equal(race[0].targetDurationSec, 14400);
  // 配速区间单调合理：T 课配速快于 E 课
  const tW = ws.find((w) => w.workoutType === 'T');
  const eW = ws.find((w) => w.workoutType === 'E');
  assert.ok(tW.paceMinSec < eW.paceMinSec, 'T 配速应快于 E');
  // 心率区间锚定：E→Z2, T→Z4
  assert.equal(eW.hrZone, 2);
  assert.equal(tW.hrZone, 4);
  // 周跑量含减量周（第 4 周低于第 3 周）
  const km = (n) => ws.filter((w) => w.weekNo === n && w.workoutType !== 'RACE')
    .reduce((s, w) => s + (w.targetDistanceM || 0), 0);
  assert.ok(km(4) < km(3), '第 4 周应为减量周');
  // 减量期最后一周量最低
  assert.ok(km(18) < km(15));
});

test('标记课表 done → adapt', async () => {
  // 把近 2 周窗口内的课表标记 done/missed（adapt 统计窗口为近 14 天）
  const today = new Date();
  const recent = planDetail.workouts.filter((w) => {
    const dt = new Date(`${w.date}T00:00:00Z`);
    return dt <= today && dt >= new Date(today.getTime() - 14 * 86400000);
  });
  // 计划从 2026-08-10 开始，若窗口内无课表则手动造数据：直接把第 1 周第 1 课标记 done 验证接口
  const target = recent[0] || planDetail.workouts[0];
  const r = await api('POST', `/plans/${planId}/workouts/${target.id}/status`, {
    status: 'done', activityId: firstActivityId,
  }, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.workout.status, 'done');
  assert.equal(r.body.workout.activityId, firstActivityId);

  const a = await api('POST', `/plans/${planId}/adapt`, {}, accessToken);
  assert.equal(a.status, 200);
  assert.ok(['maintain', 'reduce_volume', 'reduce_intensity'].includes(a.body.suggestion.action));
  assert.ok(typeof a.body.suggestion.completionRate === 'number');
  assert.ok(typeof a.body.adjustedFutureWorkouts === 'number');
});

test('stats dashboard / weekly / hr-distribution', async () => {
  let r = await api('GET', '/stats/dashboard', undefined, accessToken);
  assert.equal(r.status, 200);
  for (const k of ['weekDistanceM', 'weekCount', 'totalActivities', 'atl', 'ctl', 'tsb']) {
    assert.equal(typeof r.body[k], 'number', `dashboard.${k} 应为数字`);
  }
  assert.ok(r.body.planProgress, '存在激活计划时应有完成度');
  assert.ok(Array.isArray(r.body.recentActivities) && r.body.recentActivities.length > 0);
  assert.ok(r.body.atl > 0 && r.body.ctl > 0);

  r = await api('GET', '/stats/weekly?weeks=10', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.weeks.length, 10);
  const kmSum = r.body.weeks.reduce((s, w) => s + w.distanceM, 0);
  assert.ok(kmSum > 100000, `近 10 周总跑量应 >100km，实际 ${kmSum / 1000}km`);

  r = await api('GET', '/stats/hr-distribution', undefined, accessToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.zones.length, 5);
  const pctSum = r.body.zones.reduce((s, z) => s + z.pct, 0);
  assert.ok(Math.abs(pctSum - 100) < 1, `各区间占比应≈100%，实际 ${pctSum}`);
  assert.ok(r.body.totalSec > 0);
});

test('登出 → refresh 失效；access token 用户隔离', async () => {
  // 登出
  let r = await api('POST', '/auth/logout', undefined, accessToken);
  assert.equal(r.status, 200);
  r = await api('POST', '/auth/refresh', { refreshToken });
  assert.equal(r.status, 401);

  // 用户隔离：另一用户看不到第一个用户的活动/计划
  r = await api('POST', '/auth/register', { email: 'other@test.com', password: 'password123' });
  const otherToken = r.body.tokens.accessToken;
  const list = await api('GET', '/activities', undefined, otherToken);
  assert.equal(list.body.total, 0);
  const plan = await api('GET', `/plans/${planId}`, undefined, otherToken);
  assert.equal(plan.status, 404);
});
