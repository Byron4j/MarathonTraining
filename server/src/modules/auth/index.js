'use strict';
// Auth 模块：注册、登录、刷新令牌、登出、me（docs/03 第 1 节）
const crypto = require('node:crypto');
const { errors } = require('../../lib/http');
const jwt = require('../../lib/jwt');
const password = require('../../lib/password');

function uuid() {
  return crypto.randomUUID();
}

function issueTokens(config, userId) {
  const accessToken = jwt.sign({ sub: userId, typ: 'access' }, config.jwtSecret, config.accessTokenTtlSec);
  const refreshToken = crypto.randomBytes(48).toString('base64url');
  return { accessToken, refreshToken, expiresIn: config.accessTokenTtlSec };
}

function storeRefreshToken(db, userId, refreshToken) {
  const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  db.prepare('UPDATE users SET refresh_token_hash = ?, updated_at = ? WHERE id = ?')
    .run(hash, Date.now(), userId);
}

function publicUser(row) {
  return { id: row.id, email: row.email, createdAt: row.created_at };
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function register(router, { db, config }) {
  router.post('/auth/register', async (req, res, ctx) => {
    const { email, password: pwd, nickname } = ctx.body || {};
    if (!email || !EMAIL_RE.test(String(email))) throw errors.badRequest('邮箱格式非法');
    if (!pwd || String(pwd).length < 8) throw errors.badRequest('密码至少 8 位');
    const emailLower = String(email).toLowerCase();
    const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(emailLower);
    if (exists) throw errors.conflict('邮箱已注册');

    const id = uuid();
    const now = Date.now();
    db.prepare('INSERT INTO users (id, email, password_hash, created_at, updated_at) VALUES (?,?,?,?,?)')
      .run(id, emailLower, password.hash(String(pwd)), now, now);
    db.prepare('INSERT INTO profiles (user_id, nickname) VALUES (?,?)').run(id, nickname || null);

    const tokens = issueTokens(config, id);
    storeRefreshToken(db, id, tokens.refreshToken);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
    return { user: publicUser(user), tokens };
  });

  router.post('/auth/login', async (req, res, ctx) => {
    const { email, password: pwd } = ctx.body || {};
    if (!email || !pwd) throw errors.badRequest('邮箱与密码必填');
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email).toLowerCase());
    if (!user || !password.verify(String(pwd), user.password_hash)) {
      throw errors.unauthorized('邮箱或密码错误');
    }
    const tokens = issueTokens(config, user.id);
    storeRefreshToken(db, user.id, tokens.refreshToken);
    return { user: publicUser(user), tokens };
  });

  // 刷新令牌（旋转）
  router.post('/auth/refresh', async (req, res, ctx) => {
    const { refreshToken } = ctx.body || {};
    if (!refreshToken) throw errors.badRequest('refreshToken 必填');
    const hash = crypto.createHash('sha256').update(String(refreshToken)).digest('hex');
    const user = db.prepare('SELECT * FROM users WHERE refresh_token_hash = ?').get(hash);
    if (!user) throw errors.unauthorized('刷新令牌无效或已吊销');
    const tokens = issueTokens(config, user.id);
    storeRefreshToken(db, user.id, tokens.refreshToken);
    return { tokens };
  });

  router.post('/auth/logout', async (req, res, ctx) => {
    db.prepare('UPDATE users SET refresh_token_hash = NULL, updated_at = ? WHERE id = ?')
      .run(Date.now(), ctx.user.id);
    return { ok: true };
  });

  router.get('/auth/me', async (req, res, ctx) => {
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.user.id);
    const profile = db.prepare('SELECT * FROM profiles WHERE user_id = ?').get(ctx.user.id);
    return { user: publicUser(user), profile: profile ? toCamelProfile(profile) : null };
  });
}

function toCamelProfile(row) {
  return {
    nickname: row.nickname,
    gender: row.gender,
    birthDate: row.birth_date,
    heightCm: row.height_cm,
    weightKg: row.weight_kg,
    restingHr: row.resting_hr,
    maxHr: row.max_hr,
    pb5kSec: row.pb_5k_sec,
    pb10kSec: row.pb_10k_sec,
    pbHalfSec: row.pb_half_sec,
    pbFullSec: row.pb_full_sec,
    weeklyKm: row.weekly_km,
    yearsRunning: row.years_running,
    hrZones: row.hr_zones_json ? JSON.parse(row.hr_zones_json) : null,
  };
}

module.exports = { register, issueTokens, toCamelProfile, uuid };
