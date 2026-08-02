'use strict';
// AES-256-GCM 令牌加解密（第三方平台凭据不落明文）
// 密钥来自 env TOKEN_SECRET；缺失时使用开发默认值并警告。
const crypto = require('node:crypto');

let warned = false;
let cachedKey = null;

function getKey() {
  if (cachedKey) return cachedKey;
  const secret = process.env.TOKEN_SECRET;
  if (!secret && !warned) {
    warned = true;
    console.warn('[crypto] TOKEN_SECRET 未设置，使用开发默认密钥（仅限本地开发，勿用于生产）');
  }
  // 任意长度 secret → SHA-256 派生 32 字节密钥
  cachedKey = crypto.createHash('sha256').update(secret || 'dev-only-token-secret-change-me').digest();
  return cachedKey;
}

// 输出 base64(iv | tag | ciphertext)
function encrypt(plain) {
  if (plain == null) return null;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const enc = Buffer.concat([cipher.update(String(plain), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString('base64');
}

function decrypt(payload) {
  if (payload == null) return null;
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
}

module.exports = { encrypt, decrypt };
