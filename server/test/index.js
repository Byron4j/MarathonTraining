'use strict';
// 兼容入口：Node 25 下 `node --test server/test/` 会把目录当模块加载，
// 提供 index.js 转发到真正的测试文件，使目录形式与文件形式均可运行。
require('./smoke.test.js');
