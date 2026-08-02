'use strict';
// 迷你 HTTP 路由器：支持 :param 路径、JSON body 解析、统一错误格式、async handler
// 错误约定见 docs/03-API接口规范.md：{ error: { code, message, details? } }

class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

const errors = {
  badRequest: (msg, details) => new HttpError(400, 'VALIDATION_ERROR', msg, details),
  unauthorized: (msg = '未登录或令牌无效') => new HttpError(401, 'UNAUTHORIZED', msg),
  tokenExpired: (msg = '令牌已过期') => new HttpError(401, 'TOKEN_EXPIRED', msg),
  forbidden: (msg = '无权限') => new HttpError(403, 'FORBIDDEN', msg),
  notFound: (msg = '资源不存在') => new HttpError(404, 'NOT_FOUND', msg),
  conflict: (msg = '资源冲突') => new HttpError(409, 'CONFLICT', msg),
  upstream: (msg = '第三方平台调用失败') => new HttpError(502, 'UPSTREAM_ERROR', msg),
  internal: (msg = '服务端错误') => new HttpError(500, 'INTERNAL_ERROR', msg),
};

function compilePath(pattern) {
  const keys = [];
  const parts = pattern.split('/').filter(Boolean).map((seg) => {
    if (seg.startsWith(':')) {
      keys.push(seg.slice(1));
      return '([^/]+)';
    }
    return seg.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  });
  return { regex: new RegExp(`^/${parts.join('/')}/?$`), keys };
}

class Router {
  constructor() {
    this.routes = [];
    this.middlewares = []; // async (req, res, ctx) => void，可抛错终止
  }

  use(fn) {
    this.middlewares.push(fn);
    return this;
  }

  add(method, pattern, handler) {
    const { regex, keys } = compilePath(pattern);
    this.routes.push({ method, pattern, regex, keys, handler });
    return this;
  }

  get(p, h) { return this.add('GET', p, h); }
  post(p, h) { return this.add('POST', p, h); }
  put(p, h) { return this.add('PUT', p, h); }
  delete(p, h) { return this.add('DELETE', p, h); }

  match(method, pathname) {
    let pathMatched = false;
    for (const r of this.routes) {
      const m = r.regex.exec(pathname);
      if (!m) continue;
      if (r.method !== method) { pathMatched = true; continue; }
      const params = {};
      r.keys.forEach((k, i) => { params[k] = decodeURIComponent(m[i + 1]); });
      return { handler: r.handler, params };
    }
    if (pathMatched) throw errors.notFound('方法或路径不存在');
    return null;
  }

  handler() {
    return async (req, res) => {
      try {
        const url = new URL(req.url, 'http://localhost');
        const pathname = url.pathname.replace(/\/+$/, '') || '/';
        const body = await readBody(req);
        const ctx = {
          req, res,
          query: Object.fromEntries(url.searchParams.entries()),
          params: {},
          body,
          user: null,
          state: {},
        };
        for (const mw of this.middlewares) {
          await mw(req, res, ctx);
          if (res.writableEnded) return;
        }
        const found = this.match(req.method, pathname);
        if (!found) throw errors.notFound(`路径不存在: ${req.method} ${pathname}`);
        ctx.params = found.params;
        const result = await found.handler(req, res, ctx);
        if (!res.writableEnded) {
          sendJson(res, 200, result === undefined ? { ok: true } : result);
        }
      } catch (err) {
        sendError(res, err);
      }
    };
  }
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 20 * 1024 * 1024) { // 20MB 上限（GPX 导入）
        reject(errors.badRequest('请求体过大'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve(null);
      const raw = Buffer.concat(chunks).toString('utf8');
      const type = String(req.headers['content-type'] || '');
      if (type.includes('application/json') || raw.trim().startsWith('{') || raw.trim().startsWith('[')) {
        try {
          resolve(JSON.parse(raw));
        } catch {
          reject(errors.badRequest('JSON 解析失败'));
        }
      } else {
        resolve(raw);
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, status, data) {
  const payload = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  });
  res.end(payload);
}

function sendError(res, err) {
  if (res.writableEnded) return;
  if (err instanceof HttpError) {
    const body = { error: { code: err.code, message: err.message } };
    if (err.details) body.error.details = err.details;
    return sendJson(res, err.status, body);
  }
  if (err && err.code === 'TOKEN_EXPIRED') {
    return sendJson(res, 401, { error: { code: 'TOKEN_EXPIRED', message: err.message } });
  }
  console.error('[http] 未处理异常:', err);
  sendJson(res, 500, { error: { code: 'INTERNAL_ERROR', message: '服务端错误' } });
}

module.exports = { Router, HttpError, errors, sendJson };
