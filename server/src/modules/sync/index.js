'use strict';
// 同步引擎 + Provider 注册表路由（docs/03 第 4 节、docs/05）
const crypto = require('node:crypto');
const { errors, sendJson } = require('../../lib/http');
const tokenCrypto = require('../../lib/crypto');
const { uuid } = require('../auth');
const { insertActivity, toCamel } = require('../activities');
const providers = require('./providers');
const { resolveVdot } = require('../plans/engine');
const { getProfile } = require('../profile');

// --- OAuth state（HMAC 签名，回调免认证校验） ---
function signState(config, userId) {
  const payload = Buffer.from(JSON.stringify({ uid: userId, ts: Date.now(), n: crypto.randomBytes(8).toString('hex') }))
    .toString('base64url');
  const sig = crypto.createHmac('sha256', config.jwtSecret).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

function verifyState(config, state) {
  const [payload, sig] = String(state || '').split('.');
  if (!payload || !sig) return null;
  const expect = crypto.createHmac('sha256', config.jwtSecret).update(payload).digest();
  const given = Buffer.from(sig, 'base64url');
  if (given.length !== expect.length || !crypto.timingSafeEqual(given, expect)) return null;
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (Date.now() - data.ts > 30 * 60 * 1000) return null; // 30 分钟有效
    return data.uid;
  } catch {
    return null;
  }
}

function connToCamel(row) {
  return {
    id: row.id,
    provider: row.provider,
    status: row.status,
    externalUserId: row.external_user_id,
    scopes: row.scopes,
    cursor: row.cursor,
    lastSyncAt: row.last_sync_at,
    lastError: row.last_error,
    createdAt: row.created_at,
  };
}

function upsertConnection(db, userId, providerKey, tokenSet, status = 'connected') {
  const existing = db.prepare('SELECT * FROM sync_connections WHERE user_id = ? AND provider = ?')
    .get(userId, providerKey);
  if (existing) {
    db.prepare(`UPDATE sync_connections SET status=?, access_token_enc=?, refresh_token_enc=?,
        token_expires_at=?, external_user_id=?, scopes=?, last_error=NULL WHERE id=?`)
      .run(
        status,
        tokenCrypto.encrypt(tokenSet.accessToken),
        tokenCrypto.encrypt(tokenSet.refreshToken),
        tokenSet.expiresAt || null,
        tokenSet.externalUserId || null,
        tokenSet.scopes || null,
        existing.id,
      );
    return existing.id;
  }
  const id = uuid();
  db.prepare(`INSERT INTO sync_connections
    (id, user_id, provider, status, access_token_enc, refresh_token_enc, token_expires_at,
     external_user_id, scopes, created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?)`)
    .run(
      id, userId, providerKey, status,
      tokenCrypto.encrypt(tokenSet.accessToken),
      tokenCrypto.encrypt(tokenSet.refreshToken),
      tokenSet.expiresAt || null,
      tokenSet.externalUserId || null,
      tokenSet.scopes || null,
      Date.now(),
    );
  return id;
}

// 同步引擎：增量拉取 → 去重入库 → 写 sync_job 审计
async function runSync(db, config, connection) {
  const provider = providers.get(connection.provider);
  if (!provider) throw errors.badRequest(`未知 provider: ${connection.provider}`);
  if (!provider.available(config)) {
    throw errors.upstream(provider.unavailableReason ? provider.unavailableReason(config) : 'Provider 不可用');
  }
  const jobId = uuid();
  db.prepare('INSERT INTO sync_jobs (id, connection_id, started_at, status) VALUES (?,?,?,?)')
    .run(jobId, connection.id, Date.now(), 'running');

  let added = 0;
  let skipped = 0;
  let maxStart = Number(connection.cursor || 0);
  try {
    const profile = getProfile(db, connection.user_id) || {};
    const { vdot } = resolveVdot({
      pbs: {
        pb5kSec: profile.pb_5k_sec, pb10kSec: profile.pb_10k_sec,
        pbHalfSec: profile.pb_half_sec, pbFullSec: profile.pb_full_sec,
      },
      weeklyKm: profile.weekly_km,
    });
    const ctx = {
      config,
      accessToken: tokenCrypto.decrypt(connection.access_token_enc),
      vdot,
      restingHr: profile.resting_hr,
      maxHr: profile.max_hr,
      weeklyKm: profile.weekly_km,
    };
    const items = await provider.fetchSince(connection.cursor, ctx);
    const existsStmt = db.prepare(
      'SELECT id FROM activities WHERE user_id = ? AND provider = ? AND external_id = ?');
    for (const raw of items) {
      const a = provider.normalize(raw);
      if (!a.externalId) { skipped += 1; continue; }
      if (existsStmt.get(connection.user_id, connection.provider, a.externalId)) {
        skipped += 1;
        continue;
      }
      insertActivity(db, connection.user_id, { ...a, provider: connection.provider });
      added += 1;
      if (a.startTime > maxStart) maxStart = a.startTime;
    }
    db.prepare('UPDATE sync_connections SET cursor=?, last_sync_at=?, last_error=NULL WHERE id=?')
      .run(String(maxStart || connection.cursor || ''), Date.now(), connection.id);
    db.prepare('UPDATE sync_jobs SET finished_at=?, status=?, added=?, skipped=? WHERE id=?')
      .run(Date.now(), 'success', added, skipped, jobId);
  } catch (err) {
    db.prepare('UPDATE sync_jobs SET finished_at=?, status=?, added=?, skipped=?, error_msg=? WHERE id=?')
      .run(Date.now(), 'error', added, skipped, String(err.message).slice(0, 500), jobId);
    db.prepare('UPDATE sync_connections SET last_sync_at=?, last_error=? WHERE id=?')
      .run(Date.now(), String(err.message).slice(0, 500), connection.id);
    throw err;
  }
  return { jobId, added, skipped };
}

function register(router, { db, config }) {
  router.get('/sync/providers', async () => ({ providers: providers.listProviders(config) }));

  router.get('/sync/connections', async (req, res, ctx) => {
    const rows = db.prepare('SELECT * FROM sync_connections WHERE user_id = ? ORDER BY created_at DESC')
      .all(ctx.user.id);
    return { connections: rows.map(connToCamel) };
  });

  // 建立连接：mock 直连；coros 返回授权 URL
  router.post('/sync/connections', async (req, res, ctx) => {
    const { provider: key } = ctx.body || {};
    const provider = providers.get(key);
    if (!provider) throw errors.badRequest(`未知 provider: ${key}（可选 mock / coros）`);
    if (!provider.available(config)) {
      throw errors.upstream(provider.unavailableReason ? provider.unavailableReason(config) : 'Provider 不可用');
    }
    if (key === 'coros') {
      // OAuth 模式：返回授权 URL，由回调完成建连
      const state = signState(config, ctx.user.id);
      return { provider: key, authorizeUrl: provider.authorizeUrl(config, state), state };
    }
    const tokenSet = await provider.connect(ctx.body || {});
    const id = upsertConnection(db, ctx.user.id, key, tokenSet);
    const row = db.prepare('SELECT * FROM sync_connections WHERE id = ?').get(id);
    return { connection: connToCamel(row) };
  });

  // 高驰 OAuth 授权链接
  router.get('/sync/connections/coros/authorize-url', async (req, res, ctx) => {
    const provider = providers.get('coros');
    if (!provider.available(config)) {
      return { status: 'unavailable', reason: provider.unavailableReason(config) };
    }
    const state = signState(config, ctx.user.id);
    return { authorizeUrl: provider.authorizeUrl(config, state), state };
  });

  // 高驰 OAuth 回调（免认证；state 验签定位用户）
  router.get('/sync/callback/coros', async (req, res, ctx) => {
    const provider = providers.get('coros');
    if (!provider.available(config)) {
      throw errors.upstream(provider.unavailableReason(config));
    }
    const userId = verifyState(config, ctx.query.state);
    if (!userId) throw errors.forbidden('state 校验失败或已过期');
    if (!ctx.query.code) throw errors.badRequest('缺少 code');
    let tokenSet;
    try {
      tokenSet = await provider.exchangeCode(config, ctx.query.code);
    } catch (err) {
      throw errors.upstream(`COROS 换 token 失败: ${err.message}`);
    }
    upsertConnection(db, userId, 'coros', tokenSet);
    // 重定向回 App
    const target = config.coros.successRedirect;
    res.writeHead(302, { Location: target });
    res.end();
  });

  router.delete('/sync/connections/:id', async (req, res, ctx) => {
    const r = db.prepare('DELETE FROM sync_connections WHERE id = ? AND user_id = ?')
      .run(ctx.params.id, ctx.user.id);
    if (r.changes === 0) throw errors.notFound('连接不存在');
    return { ok: true };
  });

  // 触发同步 → {jobId, added, skipped}
  router.post('/sync/connections/:id/sync', async (req, res, ctx) => {
    const conn = db.prepare('SELECT * FROM sync_connections WHERE id = ? AND user_id = ?')
      .get(ctx.params.id, ctx.user.id);
    if (!conn) throw errors.notFound('连接不存在');
    try {
      return await runSync(db, config, conn);
    } catch (err) {
      if (err.status) throw err;
      throw errors.upstream(`同步失败: ${err.message}`);
    }
  });

  router.get('/sync/jobs', async (req, res, ctx) => {
    const limit = Math.min(100, Math.max(1, Number(ctx.query.limit) || 20));
    const rows = db.prepare(`SELECT j.* FROM sync_jobs j
      JOIN sync_connections c ON c.id = j.connection_id
      WHERE c.user_id = ? ORDER BY j.started_at DESC LIMIT ?`).all(ctx.user.id, limit);
    return {
      jobs: rows.map((j) => ({
        id: j.id, connectionId: j.connection_id, startedAt: j.started_at, finishedAt: j.finished_at,
        status: j.status, added: j.added, skipped: j.skipped, errorMsg: j.error_msg,
      })),
    };
  });
}

module.exports = { register, runSync };
