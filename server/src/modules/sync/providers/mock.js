'use strict';
// Mock Provider：一键生成近 8 周拟真训练数据（每周 3–5 次，配速/心率围绕用户 VDOT 波动）
// 用于：无设备体验、开发调试、自动化测试种子数据（docs/05 第 5 节）
const { paceRange } = require('../../plans/engine');

// 简易可复现伪随机
function mulberry32(seed) {
  let a = seed >>> 0;
  return function rand() {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const provider = {
  key: 'mock',
  name: '模拟数据（开发调试）',
  capabilities: ['connect', 'fetchSince'],
  available: () => true,

  // mock 直连：无需外部凭据
  async connect() {
    return {
      accessToken: `mock-${Date.now()}`,
      refreshToken: null,
      expiresAt: null,
      externalUserId: 'mock-runner',
      scopes: 'activities:read',
    };
  },

  // 生成近 8 周活动；ctx = { vdot, restingHr, maxHr, weeklyKm }
  async fetchSince(cursor, ctx = {}) {
    const vdot = ctx.vdot || 40;
    const ePace = paceRange(vdot, 'E');
    const tPace = paceRange(vdot, 'T');
    const resting = ctx.restingHr || 60;
    const maxHr = ctx.maxHr || 185;
    // 按日取整基准时间 + 每个课次独立种子：生成数据与游标过滤完全无关，
    // 保证同一天内多次同步结果确定一致（增量游标 + 唯一约束去重生效）
    const now = Math.floor(Date.now() / 86400000) * 86400000;

    const items = [];
    for (let w = 7; w >= 0; w -= 1) {
      const randWeek = mulberry32(42 + w);
      const sessions = 3 + Math.floor(randWeek() * 3); // 每周 3–5 次
      const days = [1, 2, 3, 4, 5, 6].sort(() => randWeek() - 0.5).slice(0, sessions).sort((a, b) => a - b);
      for (const d of days) {
        const rand = mulberry32(42 * 1000 + w * 10 + d); // 课次级独立种子
        const dayOffset = w * 7 + (6 - d);
        const start = new Date(now - dayOffset * 86400000);
        start.setHours(6 + Math.floor(rand() * 12), Math.floor(rand() * 60), 0, 0);
        const startTime = start.getTime();
        const idSuffix = Math.round(rand() * 1e6);
        if (cursor && startTime < Number(cursor)) continue; // 增量游标（边界条目重拉由唯一约束去重）

        const isQuality = rand() < 0.25;
        const isLong = d === 6;
        const basePace = isQuality
          ? tPace.fast + rand() * 10
          : ePace.fast + rand() * (ePace.slow - ePace.fast);
        const km = isLong ? 14 + rand() * 8 : 6 + rand() * 6;
        const distanceM = Math.round(km * 1000);
        const durationSec = Math.round(km * basePace);
        const hrRatio = isQuality ? 0.82 + rand() * 0.06 : 0.68 + rand() * 0.1;
        const avgHr = Math.round(resting + (maxHr - resting) * hrRatio);
        items.push({
          externalId: `mock-${startTime}-${idSuffix}`,
          sport: 'run',
          startTime,
          durationSec,
          distanceM,
          elevationGainM: Math.round(rand() * 120),
          avgPaceSecPerKm: Math.round(basePace),
          avgHr,
          maxHr: Math.min(maxHr, avgHr + Math.round(8 + rand() * 15)),
          avgCadence: 170 + Math.round(rand() * 14),
          calories: Math.round(km * 62),
          trainingEffect: Math.round((1.5 + rand() * 3) * 10) / 10,
        });
      }
    }
    return items.sort((a, b) => a.startTime - b.startTime);
  },

  normalize(raw) {
    return raw; // mock 数据已是统一模型
  },
};

module.exports = provider;
