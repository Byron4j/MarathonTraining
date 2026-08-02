'use strict';
// 入口：加载配置、建库、启动 HTTP（docs/01-系统架构设计.md 第 3/6 节）
// 启动：node server/src/index.js（默认 :8080，DB 文件 server/data/app.db，自动建目录）
const http = require('node:http');
const config = require('./config');
const { openDatabase } = require('./db/connection');
const { Router, errors } = require('./lib/http');
const jwt = require('./lib/jwt');

const authModule = require('./modules/auth');
const profileModule = require('./modules/profile');
const activitiesModule = require('./modules/activities');
const syncModule = require('./modules/sync');
const plansModule = require('./modules/plans');
const statsModule = require('./modules/stats');

// 免认证路径（其余全部需 Bearer token）
const PUBLIC_PATHS = new Set([
  'GET /health',
  'GET /api/v1/health',
  'POST /api/v1/auth/register',
  'POST /api/v1/auth/login',
  'POST /api/v1/auth/refresh',
  'GET /api/v1/sync/callback/coros',
]);

function createApp(options = {}) {
  const cfg = { ...config, ...options };
  const db = options.db || openDatabase(cfg.dbPath);
  const router = new Router();
  const deps = { db, config: cfg };

  // CORS 预检
  router.use(async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
      });
      res.end();
    }
  });

  // 认证中间件：Bearer JWT → ctx.user；所有查询按 user_id 隔离
  router.use(async (req, res, ctx) => {
    const url = new URL(req.url, 'http://localhost');
    const pathname = url.pathname.replace(/\/+$/, '') || '/';
    if (PUBLIC_PATHS.has(`${req.method} ${pathname}`)) return;
    const header = String(req.headers.authorization || '');
    if (!header.startsWith('Bearer ')) throw errors.unauthorized('缺少 Authorization: Bearer 令牌');
    let payload;
    try {
      payload = jwt.verify(header.slice(7), cfg.jwtSecret);
    } catch (err) {
      if (err.code === 'TOKEN_EXPIRED') throw errors.tokenExpired(err.message);
      throw errors.unauthorized(err.message || '令牌无效');
    }
    const user = db.prepare('SELECT id, email FROM users WHERE id = ?').get(payload.sub);
    if (!user) throw errors.unauthorized('用户不存在');
    ctx.user = user;
  });

  // 系统
  const health = async () => ({ status: 'ok', version: cfg.version });
  router.get('/health', health);
  router.get(`${cfg.apiBase}/health`, health);

  // 业务模块（统一挂在 /api/v1 下）
  const api = new Router();
  // 复用同一中间件链：直接把子路由注册到主 router，路径加前缀
  for (const mod of [authModule, profileModule, activitiesModule, syncModule, plansModule, statsModule]) {
    mod.register({
      get: (p, h) => router.get(`${cfg.apiBase}${p}`, h),
      post: (p, h) => router.post(`${cfg.apiBase}${p}`, h),
      put: (p, h) => router.put(`${cfg.apiBase}${p}`, h),
      delete: (p, h) => router.delete(`${cfg.apiBase}${p}`, h),
    }, deps);
  }

  return { router, db, config: cfg };
}

function createServer(options = {}) {
  const app = createApp(options);
  const server = http.createServer(app.router.handler());
  return { server, ...app };
}

if (require.main === module) {
  const { server, config: cfg } = createServer();
  server.listen(cfg.port, () => {
    console.log(`[server] 马拉松训练后端已启动: http://localhost:${cfg.port}${cfg.apiBase} (db: ${cfg.dbPath})`);
  });
  for (const sig of ['SIGINT', 'SIGTERM']) {
    process.on(sig, () => server.close(() => process.exit(0)));
  }
}

module.exports = { createServer, createApp };
