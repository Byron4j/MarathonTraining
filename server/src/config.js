'use strict';
// 环境变量与默认值（见 docs/01-系统架构设计.md 第 2/6 节、docs/05-第三方平台接入.md 第 1 节）
const path = require('node:path');

const SERVER_ROOT = path.resolve(__dirname, '..');

const config = {
  port: Number(process.env.PORT || 8080),
  dbPath: process.env.DB_PATH || path.join(SERVER_ROOT, 'data', 'app.db'),
  apiBase: process.env.API_BASE || '/api/v1',
  version: '1.0.0',

  jwtSecret: process.env.JWT_SECRET || 'dev-only-jwt-secret-change-me',
  accessTokenTtlSec: Number(process.env.ACCESS_TOKEN_TTL_SEC || 15 * 60), // 15min
  refreshTokenTtlSec: Number(process.env.REFRESH_TOKEN_TTL_SEC || 30 * 24 * 3600), // 30d

  // AES-256-GCM 密钥（第三方令牌加密）；缺失时用开发默认值并警告
  tokenSecret: process.env.TOKEN_SECRET || '',

  // 高驰 COROS OAuth（缺失 → provider 状态 unavailable，不阻塞其它功能）
  coros: {
    clientId: process.env.COROS_CLIENT_ID || '',
    clientSecret: process.env.COROS_CLIENT_SECRET || '',
    redirectUri: process.env.COROS_REDIRECT_URI || '',
    apiBase: process.env.COROS_API_BASE || 'https://open.coros.com',
    successRedirect: process.env.COROS_SUCCESS_REDIRECT || 'paceforge://sync/success',
  },

  httpTimeoutMs: Number(process.env.UPSTREAM_TIMEOUT_MS || 10000),
};

if (!process.env.JWT_SECRET) {
  console.warn('[config] JWT_SECRET 未设置，使用开发默认值（仅限本地开发）');
}

module.exports = config;
