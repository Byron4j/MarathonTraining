'use strict';
// 高驰 COROS Provider（docs/05 第 1 节）：OAuth2 授权码模式 + 运动列表增量拉取。
// 凭据缺失 → status=unavailable，接口正常返回说明，不得崩溃。
// 真实 HTTP 调用用全局 fetch，带超时/错误处理。

const provider = {
  key: 'coros',
  name: '高驰 COROS',
  capabilities: ['oauth', 'connect', 'fetchSince', 'detail'],

  available(config) {
    return Boolean(config.coros.clientId && config.coros.clientSecret);
  },

  unavailableReason(config) {
    return '未配置 COROS_CLIENT_ID / COROS_CLIENT_SECRET（见 docs/05-第三方平台接入.md）';
  },

  // 生成 OAuth 授权链接
  authorizeUrl(config, state) {
    const redirect = config.coros.redirectUri
      || `http://localhost:${config.port}${config.apiBase}/sync/callback/coros`;
    const url = new URL(`${config.coros.apiBase}/oauth2/authorize`);
    url.searchParams.set('client_id', config.coros.clientId);
    url.searchParams.set('redirect_uri', redirect);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('state', state);
    return url.toString();
  },

  // code 换 token
  async exchangeCode(config, code) {
    const redirect = config.coros.redirectUri
      || `http://localhost:${config.port}${config.apiBase}/sync/callback/coros`;
    const url = new URL(`${config.coros.apiBase}/oauth2/accesstoken`);
    url.searchParams.set('client_id', config.coros.clientId);
    url.searchParams.set('client_secret', config.coros.clientSecret);
    url.searchParams.set('grant_type', 'authorization_code');
    url.searchParams.set('redirect_uri', redirect);
    url.searchParams.set('code', code);
    const data = await fetchJson(url.toString(), { method: 'POST' }, config.httpTimeoutMs);
    if (!data || !data.access_token) {
      throw new Error(`COROS 换 token 失败: ${JSON.stringify(data)}`);
    }
    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token || null,
      expiresAt: data.expires_in ? Date.now() + Number(data.expires_in) * 1000 : null,
      externalUserId: data.open_id || data.openId || null,
      scopes: data.scope || null,
    };
  },

  // 增量拉取运动列表（按时间游标）
  async fetchSince(cursor, ctx = {}) {
    const { config, accessToken } = ctx;
    const body = {
      startTime: cursor ? Math.floor(Number(cursor) / 1000) : Math.floor((Date.now() - 56 * 86400000) / 1000),
      endTime: Math.floor(Date.now() / 1000),
    };
    const data = await fetchJson(`${config.coros.apiBase}/v2/coros/sport/list`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        accesstoken: accessToken,
        client: config.coros.clientId,
      },
      body: JSON.stringify(body),
    }, config.httpTimeoutMs);
    const list = (data && (data.data || data.sportList)) || [];
    return list.map((raw) => provider.normalize(raw));
  },

  // 平台原始数据 → 统一活动模型
  // 字段映射：distance→distance_m、duration→duration_sec、avgHeartRate→avg_hr、
  // avgSpeed→配速换算、stepFrequency→avg_cadence
  normalize(raw) {
    const distanceM = Number(raw.distance) || 0;
    const durationSec = Number(raw.duration) || 0;
    const avgSpeed = Number(raw.avgSpeed) || 0; // m/s
    return {
      externalId: String(raw.labelId || raw.id || raw.sportId || ''),
      sport: 'run',
      startTime: raw.startTime ? Number(raw.startTime) * 1000 : (raw.start_time || Date.now()),
      durationSec,
      distanceM,
      elevationGainM: raw.ascent != null ? Number(raw.ascent) : null,
      avgPaceSecPerKm: avgSpeed > 0 ? Math.round(1000 / avgSpeed)
        : (distanceM > 0 ? Math.round(durationSec / (distanceM / 1000)) : null),
      avgHr: raw.avgHeartRate != null ? Number(raw.avgHeartRate) : null,
      maxHr: raw.maxHeartRate != null ? Number(raw.maxHeartRate) : null,
      avgCadence: raw.stepFrequency != null ? Number(raw.stepFrequency) : null,
      calories: raw.calorie != null ? Number(raw.calorie) : null,
      trainingEffect: raw.trainingEffect != null ? Number(raw.trainingEffect) : null,
      rawJson: JSON.stringify(raw),
    };
  },
};

async function fetchJson(url, options, timeoutMs = 10000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const resp = await fetch(url, { ...options, signal: ctrl.signal });
    const text = await resp.text();
    if (!resp.ok) throw new Error(`HTTP ${resp.status}: ${text.slice(0, 200)}`);
    return text ? JSON.parse(text) : {};
  } finally {
    clearTimeout(timer);
  }
}

module.exports = provider;
