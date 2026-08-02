'use strict';
// PBKDF2-HMAC-SHA256 密码哈希，格式 pbkdf2$iterations$salt$hash（base64）
const crypto = require('node:crypto');

const ITERATIONS = 120000;
const KEY_LEN = 32;
const DIGEST = 'sha256';

function hash(password) {
  const salt = crypto.randomBytes(16).toString('base64');
  const derived = crypto.pbkdf2Sync(String(password), salt, ITERATIONS, KEY_LEN, DIGEST).toString('base64');
  return `pbkdf2$${ITERATIONS}$${salt}$${derived}`;
}

function verify(password, stored) {
  if (typeof stored !== 'string') return false;
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iter = Number(parts[1]);
  const salt = parts[2];
  const expected = Buffer.from(parts[3], 'base64');
  const derived = crypto.pbkdf2Sync(String(password), salt, iter, expected.length, DIGEST);
  return derived.length === expected.length && crypto.timingSafeEqual(derived, expected);
}

module.exports = { hash, verify };
