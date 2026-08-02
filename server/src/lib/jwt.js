'use strict';
// HS256 JWT 签发与校验（crypto HMAC + base64url，零依赖）
const crypto = require('node:crypto');

function b64url(input) {
  return Buffer.from(input).toString('base64url');
}

function sign(payload, secret, expiresInSec) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const body = { ...payload, iat: now, exp: now + expiresInSec };
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(body))}`;
  const sig = crypto.createHmac('sha256', secret).update(data).digest('base64url');
  return `${data}.${sig}`;
}

class JwtError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function verify(token, secret) {
  if (typeof token !== 'string') throw new JwtError('UNAUTHORIZED', '缺少令牌');
  const parts = token.split('.');
  if (parts.length !== 3) throw new JwtError('UNAUTHORIZED', '令牌格式非法');
  const [h, p, sig] = parts;
  const expect = crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest();
  let given;
  try {
    given = Buffer.from(sig, 'base64url');
  } catch {
    throw new JwtError('UNAUTHORIZED', '令牌签名非法');
  }
  if (given.length !== expect.length || !crypto.timingSafeEqual(given, expect)) {
    throw new JwtError('UNAUTHORIZED', '令牌签名不匹配');
  }
  let payload;
  try {
    payload = JSON.parse(Buffer.from(p, 'base64url').toString('utf8'));
  } catch {
    throw new JwtError('UNAUTHORIZED', '令牌载荷非法');
  }
  if (typeof payload.exp === 'number' && payload.exp < Math.floor(Date.now() / 1000)) {
    throw new JwtError('TOKEN_EXPIRED', '令牌已过期');
  }
  return payload;
}

module.exports = { sign, verify, JwtError };
