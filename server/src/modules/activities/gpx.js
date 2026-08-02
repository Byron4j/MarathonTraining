'use strict';
// GPX 解析（docs/05 第 2 节）：解析 trkpt 的 time/lat/lon/ele/hr，
// Haversine 算距离，算配速/均心率，指纹去重。
const crypto = require('node:crypto');

function haversineM(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLon = (lon2 - lon1) * rad;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function attr(tag, name) {
  const m = new RegExp(`${name}="([^"]*)"`).exec(tag);
  return m ? m[1] : null;
}

function tagContent(xml, tag) {
  const m = new RegExp(`<(?:[\\w.]+:)?${tag}[^>]*>([^<]*)</(?:[\\w.]+:)?${tag}>`).exec(xml);
  return m ? m[1].trim() : null;
}

// 解析 GPX → 统一活动模型字段
function parseGpx(xml, filename) {
  if (typeof xml !== 'string' || !xml.includes('<trkpt')) {
    throw new Error('不是有效的 GPX 文件（缺少 trkpt）');
  }
  const points = [];
  const re = /<trkpt\b[^>]*>[\s\S]*?<\/trkpt>/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    const block = m[0];
    const openTag = block.slice(0, block.indexOf('>') + 1);
    const lat = Number(attr(openTag, 'lat'));
    const lon = Number(attr(openTag, 'lon'));
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    const ele = tagContent(block, 'ele');
    const time = tagContent(block, 'time');
    const hr = tagContent(block, 'hr');
    points.push({
      lat, lon,
      ele: ele != null ? Number(ele) : null,
      time: time ? Date.parse(time) : null,
      hr: hr != null ? Number(hr) : null,
    });
  }
  if (points.length < 2) throw new Error('GPX 轨迹点不足（<2）');

  let distance = 0;
  let eleGain = 0;
  const hrs = [];
  for (let i = 1; i < points.length; i += 1) {
    const p = points[i];
    const q = points[i - 1];
    const d = haversineM(q.lat, q.lon, p.lat, p.lon);
    if (d < 1000) distance += d; // 过滤 GPS 异常跳点（相邻点 >1km 视为漂移）
    if (p.ele != null && q.ele != null && p.ele > q.ele) eleGain += p.ele - q.ele;
  }
  for (const p of points) if (p.hr != null && p.hr > 30 && p.hr < 230) hrs.push(p.hr);

  const times = points.map((p) => p.time).filter((t) => t != null);
  if (times.length < 2) throw new Error('GPX 缺少时间信息');
  const startTime = Math.min(...times);
  const endTime = Math.max(...times);
  const durationSec = Math.round((endTime - startTime) / 1000);
  if (durationSec <= 0) throw new Error('GPX 时长非法');

  const avgHr = hrs.length ? Math.round(hrs.reduce((a, b) => a + b, 0) / hrs.length) : null;
  const maxHr = hrs.length ? Math.max(...hrs) : null;

  // 指纹去重：开始时间 + 距离 + 时长
  const fingerprint = crypto.createHash('sha1')
    .update(`${startTime}|${Math.round(distance)}|${durationSec}`)
    .digest('hex');

  return {
    provider: 'file-gpx',
    externalId: `gpx-${fingerprint}`,
    sport: 'run',
    startTime,
    durationSec,
    distanceM: Math.round(distance),
    elevationGainM: Math.round(eleGain * 10) / 10,
    avgPaceSecPerKm: distance > 0 ? Math.round(durationSec / (distance / 1000)) : null,
    avgHr,
    maxHr,
    sourceFile: filename || null,
  };
}

module.exports = { parseGpx, haversineM };
