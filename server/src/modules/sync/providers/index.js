'use strict';
// Provider 注册表（插件架构，docs/01 第 5.1 节）
// 新增平台只需实现 Provider 接口并在此注册；garmin/huawei 预留。
const mock = require('./mock');
const coros = require('./coros');

const registry = new Map();
registry.set(mock.key, mock);
registry.set(coros.key, coros);

// 预留键（下一迭代）
const reserved = [
  { key: 'garmin', name: '佳明 Garmin（下一迭代，可用文件导入）' },
  { key: 'huawei', name: '华为 Huawei（下一迭代，可用文件导入）' },
];

function get(key) {
  return registry.get(key) || null;
}

function listProviders(config) {
  const out = [];
  for (const p of registry.values()) {
    const available = p.available(config);
    out.push({
      key: p.key,
      name: p.name,
      capabilities: p.capabilities,
      status: available ? 'available' : 'unavailable',
      reason: available ? null : (p.unavailableReason ? p.unavailableReason(config) : '未配置凭据'),
    });
  }
  for (const r of reserved) {
    out.push({ key: r.key, name: r.name, capabilities: ['fileImport'], status: 'reserved', reason: '下一迭代接入，当前可走 GPX 文件导入' });
  }
  return out;
}

module.exports = { get, listProviders };
