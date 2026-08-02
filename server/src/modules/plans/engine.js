'use strict';
// 训练计划引擎（纯函数，无副作用）—— docs/04-训练计划算法.md
// 基于 Jack Daniels VDOT 体系 + 经典周期化理论。

const RACE_DISTANCE_M = { '5k': 5000, '10k': 10000, half: 21097.5, full: 42195 };
const RACE_NAMES = { '5k': '5K', '10k': '10K', half: '半程马拉松', full: '全程马拉松' };

// ---------------------------------------------------------------------------
// 1. 能力评估：VDOT（Daniels 公式）
// ---------------------------------------------------------------------------

// 由比赛成绩反推 VDOT：distanceM 米，timeSec 秒
function vdotFromRace(distanceM, timeSec) {
  const t = timeSec / 60; // 分钟
  const v = distanceM / t; // 速度 m/min
  const vo2 = -4.6 + 0.182258 * v + 0.000104 * v * v;
  const pct = 0.8 + 0.1894393 * Math.exp(-0.012778 * t) + 0.2989558 * Math.exp(-0.1932605 * t);
  return vo2 / pct;
}

// 由档案 PB 取最高 VDOT；无 PB 返回 null
function vdotFromPbs(pbs) {
  const entries = [
    ['pb5kSec', RACE_DISTANCE_M['5k']],
    ['pb10kSec', RACE_DISTANCE_M['10k']],
    ['pbHalfSec', RACE_DISTANCE_M.half],
    ['pbFullSec', RACE_DISTANCE_M.full],
  ];
  let best = null;
  for (const [key, dist] of entries) {
    const sec = pbs && pbs[key];
    if (typeof sec === 'number' && sec > 0) {
      const v = vdotFromRace(dist, sec);
      if (best === null || v > best) best = v;
    }
  }
  return best;
}

// 无 PB 时用当前周跑量保守估计（下限 30，上限 55）
function estimateVdotFromWeeklyKm(weeklyKm) {
  const km = Number(weeklyKm) || 0;
  const v = 30 + Math.min(20, km * 0.35);
  return Math.max(30, Math.min(55, v));
}

// resolveVdot：显式 vdot > PB 反推 > 周跑量估计
function resolveVdot(input) {
  if (typeof input.vdot === 'number' && input.vdot >= 20 && input.vdot <= 85) {
    return { vdot: round1(input.vdot), source: 'input' };
  }
  const fromPb = vdotFromPbs(input.pbs || {});
  if (fromPb !== null) return { vdot: round1(fromPb), source: 'pb' };
  return { vdot: round1(estimateVdotFromWeeklyKm(input.weeklyKm)), source: 'estimate' };
}

// ---------------------------------------------------------------------------
// 2. 训练配速区间（Daniels VDOT 30–60 配速表，每 1 VDOT 一行 + 线性插值）
// ---------------------------------------------------------------------------

// 各课型强度基准（%VO2max，[低端强度=慢配速, 高端强度=快配速]）
// 锚定 docs/04 第 2 节示例：VDOT40→T≈4:46、M≈5:12；VDOT50→T≈3:54、M≈4:11、R200m≈41s
const INTENSITY = {
  E: [0.65, 0.79],
  M: [0.8, 0.88],
  T: [0.94, 0.97],
  I: [1.0, 1.05],
  R: [1.08, 1.15],
};

// 给定 VDOT 与 %VO2max 求配速（秒/公里），解氧耗方程
function paceAtFraction(vdot, fraction) {
  const target = 4.6 + fraction * vdot;
  // 0.000104 v² + 0.182258 v − target = 0
  const disc = 0.182258 * 0.182258 + 4 * 0.000104 * target;
  const v = (-0.182258 + Math.sqrt(disc)) / (2 * 0.000104); // m/min
  return 60000 / v; // 秒/公里
}

// 生成 VDOT 30–60 配速表（每 1 VDOT 一行；{E:[slow,fast], M, T, I, R}，秒/公里）
function buildPaceTable() {
  const table = {};
  for (let vdot = 30; vdot <= 60; vdot += 1) {
    const row = {};
    for (const [type, [lo, hi]] of Object.entries(INTENSITY)) {
      row[type] = [Math.round(paceAtFraction(vdot, lo)), Math.round(paceAtFraction(vdot, hi))];
    }
    table[vdot] = row;
  }
  return table;
}
const PACE_TABLE = buildPaceTable();

// 任意 VDOT 配速区间：整数行之间线性插值（30 以下/60 以上取边界）
function paceRange(vdot, type) {
  const lo = Math.max(30, Math.min(59, Math.floor(vdot)));
  const hi = lo + 1;
  const frac = Math.max(0, Math.min(1, vdot - lo));
  const a = PACE_TABLE[lo][type];
  const b = PACE_TABLE[hi][type];
  const interp = (x, y) => Math.round(x + (y - x) * frac);
  // 返回 [快配速(fast), 慢配速(slow)]，秒/公里
  return { fast: interp(a[1], b[1]), slow: interp(a[0], b[0]) };
}

function allPaceRanges(vdot) {
  const out = {};
  for (const type of Object.keys(INTENSITY)) out[type] = paceRange(vdot, type);
  return out;
}

// ---------------------------------------------------------------------------
// 3. 心率区间（储备心率法 Karvonen）
// ---------------------------------------------------------------------------

const HR_ZONE_DEFS = [
  { zone: 1, name: '恢复', lo: 0.5, hi: 0.6 },
  { zone: 2, name: '有氧/轻松', lo: 0.6, hi: 0.7 },
  { zone: 3, name: '马拉松配速', lo: 0.7, hi: 0.8 },
  { zone: 4, name: '乳酸门槛', lo: 0.8, hi: 0.9 },
  { zone: 5, name: '间歇/冲刺', lo: 0.9, hi: 1.0 },
];

function hrZones(restingHr, maxHr) {
  const resting = Number(restingHr) || 60;
  const max = Number(maxHr) || 190;
  const hrr = max - resting;
  return HR_ZONE_DEFS.map((z) => ({
    zone: z.zone,
    name: z.name,
    pctLo: z.lo,
    pctHi: z.hi,
    hrLo: Math.round(resting + hrr * z.lo),
    hrHi: Math.round(resting + hrr * z.hi),
  }));
}

// 课型 → 心率区间
const TYPE_HR_ZONE = { E: 2, M: 3, T: 4, I: 5, R: 5, L: 2, RECOVERY: 1, XT: 2, REST: 1, RACE: 4 };
// 课型 → 配速锚定
const TYPE_PACE = { E: 'E', M: 'M', T: 'T', I: 'I', R: 'R', L: 'E', RECOVERY: 'E', RACE: 'M' };

// ---------------------------------------------------------------------------
// 4. 周期化结构 + 周跑量曲线
// ---------------------------------------------------------------------------

const PEAK_CAP_KM = { '5k': 35, '10k': 50, half: 65, full: 90 };
const MIN_START_KM = { '5k': 15, '10k': 20, half: 25, full: 30 };
const TAPER_WEEKS = { '5k': 1, '10k': 2, half: 2, full: 3 };

// 阶段划分：基础 ~35% / 进展 ~30% / 巅峰 ~20% / 减量 ~15%
function phaseLabels(weeks, raceType) {
  let taper = Math.min(TAPER_WEEKS[raceType] || 2, Math.max(1, Math.ceil(weeks * 0.2)));
  if (weeks <= 6) taper = 1;
  const base = Math.max(1, Math.round(weeks * 0.35));
  const build = Math.max(1, Math.round(weeks * 0.3));
  let peak = weeks - base - build - taper;
  if (peak < 1) peak = 1;
  const labels = [];
  for (let i = 0; i < weeks; i += 1) {
    if (i < base) labels.push('base');
    else if (i < base + build) labels.push('build');
    else if (i < base + build + peak) labels.push('peak');
    else labels.push('taper');
  }
  return labels;
}

// 周跑量曲线：起始量 = max(当前周跑量, 距离下限)；+5~8% 递增；每 4 周减量 −25%；峰值封顶随 VDOT 缩放
function buildWeekCurve(weeks, raceType, currentWeeklyKm, vdot) {
  const labels = phaseLabels(weeks, raceType);
  const scale = Math.max(0.7, Math.min(1.2, vdot / 45));
  const cap = PEAK_CAP_KM[raceType] * scale;
  let km = Math.max(Number(currentWeeklyKm) || 0, MIN_START_KM[raceType]);
  const weeksOut = [];
  for (let i = 0; i < weeks; i += 1) {
    const weekNo = i + 1;
    const phase = labels[i];
    if (i > 0) {
      if (phase === 'taper' && labels[i - 1] !== 'taper') {
        km *= 0.7; // 进入减量期
      } else if (phase === 'taper') {
        km *= 0.65; // 减量期继续降量保强度
      } else if (weekNo % 4 === 0) {
        km *= 0.75; // 每 4 周一个减量周 −25%
      } else {
        km *= 1.05 + ((weekNo % 3 === 1) ? 0.03 : 0); // +5~8% 递增
      }
    }
    if (phase !== 'taper') km = Math.min(km, cap);
    weeksOut.push({ weekNo, phase, targetKm: round1(km), recovery: weekNo % 4 === 0 && phase !== 'taper' });
  }
  return weeksOut;
}

// ---------------------------------------------------------------------------
// 5. 周内课表模板（按训练次数）
// ---------------------------------------------------------------------------

// day_of_week: 1=周一 … 7=周日
function pickTemplate(sessionsPerWeek) {
  switch (sessionsPerWeek) {
    case 3:
      return [{ dow: 2, type: 'Q1' }, { dow: 4, type: 'E' }, { dow: 7, type: 'L' }];
    case 4:
      return [{ dow: 2, type: 'Q1' }, { dow: 4, type: 'E' }, { dow: 6, type: 'M' }, { dow: 7, type: 'L' }];
    case 5:
      return [
        { dow: 2, type: 'Q1' }, { dow: 3, type: 'RECOVERY' }, { dow: 4, type: 'E' },
        { dow: 6, type: 'M' }, { dow: 7, type: 'L' },
      ];
    case 6:
      return [
        { dow: 1, type: 'RECOVERY' }, { dow: 2, type: 'Q1' }, { dow: 3, type: 'E' },
        { dow: 4, type: 'E' }, { dow: 6, type: 'M' }, { dow: 7, type: 'L' },
      ];
    default:
      return null; // 7 练不建议
  }
}

// 质量课具体化：基础期 T 为主；进展期 T/I 轮换；巅峰期 I/T 轮换 + M 配比；减量期 T 保强度
function assignQuality(phase, weekNo) {
  switch (phase) {
    case 'base': return 'T';
    case 'build': return weekNo % 2 === 0 ? 'I' : 'T';
    case 'peak': return weekNo % 2 === 0 ? 'T' : 'I';
    case 'taper': return 'T';
    default: return 'T';
  }
}

// ---------------------------------------------------------------------------
// 6. 课表生成
// ---------------------------------------------------------------------------

function nextMonday(from = new Date()) {
  const d = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate()));
  const dow = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + (8 - dow));
  return d;
}

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

function addDays(dateStr, days) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return toDateStr(d);
}

const TYPE_TITLES = {
  E: '轻松跑', M: '马拉松配速跑', T: '乳酸门槛节奏跑', I: '间歇训练', R: '重复跑',
  L: '长距离拉练', RECOVERY: '恢复跑', XT: '交叉训练', REST: '休息', RACE: '比赛日',
};

const PHASE_NAMES = { base: '基础期', build: '进展期', peak: '巅峰期', taper: '减量期' };

function fmtPace(sec) {
  if (!sec) return '';
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

// 周内跑量分配：质量课 ≤ 周跑量 25%，L ≤ 35%（全马 L 上限 32–35km 或 150min 先到为准）
function splitVolume(weekKm, slots, raceType, vdot) {
  const ePace = paceRange(vdot, 'E');
  const midE = (ePace.fast + ePace.slow) / 2;
  const out = new Array(slots.length).fill(0);
  const idxL = slots.findIndex((s) => s.type === 'L');
  const idxQ = slots.findIndex((s) => s.type === 'Q1');

  let remaining = weekKm;
  if (idxL >= 0) {
    let l = Math.min(weekKm * 0.35, weekKm);
    if (raceType === 'full') {
      const capByTime = (150 * 60) / midE; // 150min 对应公里数
      l = Math.min(l, 34, capByTime);
    } else if (raceType === 'half') {
      l = Math.min(l, 24);
    } else {
      l = Math.min(l, 18);
    }
    out[idxL] = l;
    remaining -= l;
  }
  if (idxQ >= 0) {
    const q = Math.min(weekKm * 0.25, remaining * 0.45);
    out[idxQ] = q;
    remaining -= q;
  }
  const restIdx = slots.map((s, i) => i).filter((i) => out[i] === 0);
  const per = restIdx.length ? remaining / restIdx.length : 0;
  for (const i of restIdx) out[i] = per;
  return out;
}

function describeWorkout(type, km, phase, paces) {
  const pr = TYPE_PACE[type] ? paces[TYPE_PACE[type]] : null;
  const paceTxt = pr ? `${fmtPace(pr.fast)}–${fmtPace(pr.slow)}/km` : '';
  switch (type) {
    case 'T': return `热身 2km 后，以门槛配速 ${paceTxt} 完成主体段落，冷身 1–2km。`;
    case 'I': return `热身 2km；400–1000m 间歇 @ ${paceTxt}，组间慢跑恢复；总量控制在周跑量 10% 内。`;
    case 'R': return `短距离重复跑 @ ${paceTxt}，充分恢复，注重跑姿与速度感。`;
    case 'M': return `以马拉松目标配速 ${paceTxt} 完成，模拟比赛节奏。`;
    case 'L': return phase === 'peak'
      ? `长距离含 M 配速段：后 1/3 段提速至 M 配速 ${fmtPace(paces.M.fast)}–${fmtPace(paces.M.slow)}/km。`
      : `有氧长距离，配速 ${paceTxt}，保持可交谈强度。`;
    case 'RECOVERY': return '极轻松恢复跑，Z1 心率，促进恢复。';
    case 'E': return `轻松跑 ${paceTxt}，结束后可加 4–6 组短加速跑（strides）。`;
    case 'RACE': return '比赛日：充分热身，按目标配速策略执行，安全完赛！';
    default: return '按计划完成。';
  }
}

// 主入口：生成完整计划（纯函数）
// input: { raceType, goalTimeSec?, weeks?, raceDate?, sessionsPerWeek, vdot?, pbs?, weeklyKm?, startDate? }
function generatePlan(input) {
  const raceType = input.raceType;
  if (!RACE_DISTANCE_M[raceType]) throw new Error(`非法 raceType: ${raceType}`);
  const sessions = Number(input.sessionsPerWeek);
  const template = pickTemplate(sessions);
  if (!template) throw new Error('每周 7 练不建议，请选 3–6 次/周');

  // 周数：weeks 与 raceDate 二选一
  let startDate = input.startDate || toDateStr(nextMonday());
  let weeks = Number(input.weeks) || 0;
  if (!weeks && input.raceDate) {
    const diffMs = new Date(`${input.raceDate}T00:00:00Z`) - new Date(`${startDate}T00:00:00Z`);
    weeks = Math.max(1, Math.round(diffMs / (7 * 86400000)) + 1);
  }
  if (!weeks || weeks < 4 || weeks > 30) throw new Error('周数需在 4–30 之间（或用 raceDate 指定）');
  const raceDate = input.raceDate || addDays(startDate, (weeks - 1) * 7 + 6);

  const { vdot, source: vdotSource } = resolveVdot(input);
  const warnings = [];
  if (vdotSource === 'estimate') warnings.push('未提供 PB，VDOT 由周跑量保守估计，建议录入 PB 后重算');

  // 目标成绩合法性校验
  let goalVdot = null;
  if (input.goalTimeSec) {
    goalVdot = round1(vdotFromRace(RACE_DISTANCE_M[raceType], input.goalTimeSec));
    if (goalVdot - vdot > 4 && weeks < 16) {
      warnings.push(`目标成绩对应 VDOT ${goalVdot}，较当前 ${vdot} 提升 >4 且周期 <16 周，目标偏激进`);
    }
  }

  const paces = allPaceRanges(vdot);
  const curve = buildWeekCurve(weeks, raceType, input.weeklyKm, vdot);

  const workouts = [];
  for (const week of curve) {
    const slots = template.map((s) => ({ ...s }));
    const isRaceWeek = week.weekNo === weeks;
    // 质量课具体化
    for (const s of slots) {
      if (s.type === 'Q1') s.type = assignQuality(week.phase, week.weekNo);
      if (week.phase === 'base' && s.type === 'M') s.type = 'E'; // 基础期 M 课降为 E
      if (week.phase === 'taper' && s.type === 'M') s.type = 'E';
    }
    // 末周嵌入 RACE 课（周日）
    if (isRaceWeek) {
      for (const s of slots) if (s.type === 'L') s.type = 'RACE';
      if (!slots.some((s) => s.type === 'RACE')) slots.push({ dow: 7, type: 'RACE' });
    }
    const kms = splitVolume(week.targetKm, slots, raceType, vdot);

    slots.forEach((s, i) => {
      const date = addDays(startDate, (week.weekNo - 1) * 7 + (s.dow - 1));
      let distKm = kms[i];
      if (s.type === 'RACE') distKm = RACE_DISTANCE_M[raceType] / 1000;
      if (s.type === 'RECOVERY') distKm = Math.min(distKm, 8);
      const pr = TYPE_PACE[s.type] ? paces[TYPE_PACE[s.type]] : null;
      // RECOVERY 配速比 E 慢 15–30s
      const paceFast = s.type === 'RECOVERY' ? pr.fast + 15 : pr ? pr.fast : null;
      const paceSlow = s.type === 'RECOVERY' ? pr.slow + 30 : pr ? pr.slow : null;
      const midPace = pr ? (paceFast + paceSlow) / 2 : 600;
      workouts.push({
        date,
        weekNo: week.weekNo,
        dayOfWeek: s.dow,
        orderInDay: 1,
        workoutType: s.type,
        title: `${TYPE_TITLES[s.type]} ${distKm >= 1 ? round1(distKm) + 'km' : ''}`.trim(),
        description: describeWorkout(s.type, distKm, week.phase, paces),
        targetDistanceM: Math.round(distKm * 1000),
        targetDurationSec: s.type === 'RACE' && input.goalTimeSec ? input.goalTimeSec : Math.round(distKm * 1000 * midPace / 1000),
        paceMinSec: paceFast,
        paceMaxSec: paceSlow,
        hrZone: TYPE_HR_ZONE[s.type] || 2,
        phase: week.phase,
      });
    });
  }

  return {
    raceType,
    raceName: RACE_NAMES[raceType],
    goalTimeSec: input.goalTimeSec || null,
    raceDate,
    startDate,
    weeks,
    sessionsPerWeek: sessions,
    vdot,
    vdotSource,
    goalVdot,
    paces,
    warnings,
    weekCurve: curve.map((w) => ({ ...w, phaseName: PHASE_NAMES[w.phase] })),
    workouts,
  };
}

// ---------------------------------------------------------------------------
// 7. 计划自适应
// ---------------------------------------------------------------------------

// 近 2 周完成率 → 调整建议
function adaptSuggestion(doneCount, missedCount, hasNewPb) {
  const total = doneCount + missedCount;
  const rate = total === 0 ? 1 : doneCount / total;
  let action;
  let factor;
  let reason;
  if (rate >= 0.85) {
    action = 'maintain'; factor = 1; reason = `近 2 周完成率 ${Math.round(rate * 100)}%，维持原计划`;
  } else if (rate >= 0.6) {
    action = 'reduce_volume'; factor = 0.9; reason = `近 2 周完成率 ${Math.round(rate * 100)}%，下周起跑量 −10%`;
  } else {
    action = 'reduce_intensity'; factor = 0.85; reason = `近 2 周完成率 ${Math.round(rate * 100)}%，质量课降一级强度且跑量 −15%`;
  }
  const out = { completionRate: round1(rate * 100) / 100, action, volumeFactor: factor, reason };
  if (hasNewPb) out.pbHint = '检测到新 PB，建议重估 VDOT 并重算后续课表';
  return out;
}

function round1(x) { return Math.round(x * 10) / 10; }

module.exports = {
  RACE_DISTANCE_M,
  RACE_NAMES,
  PACE_TABLE,
  HR_ZONE_DEFS,
  vdotFromRace,
  vdotFromPbs,
  estimateVdotFromWeeklyKm,
  resolveVdot,
  paceAtFraction,
  paceRange,
  allPaceRanges,
  hrZones,
  phaseLabels,
  buildWeekCurve,
  pickTemplate,
  assignQuality,
  generatePlan,
  adaptSuggestion,
  fmtPace,
  nextMonday,
};
