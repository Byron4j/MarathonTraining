# PaceForge · 马拉松训练平台

汇聚高驰 / 佳明 / 华为多平台数据，基于训练数据智能生成 5K / 10K / 半马 / 全马周期化训练计划的跨端应用。

## 仓库结构

```
├── docs/        # 完整方案文档（PRD / 架构 / 数据模型 / API / 算法 / 平台接入 / UI规范 / 路线图）
├── server/      # Node.js 后端（零依赖：node:http + node:sqlite，开箱即跑）
└── app/         # Flutter 客户端（iOS / Android / 平板 / 折叠屏自适应）
```

## 文档导航

| 文档 | 内容 |
|---|---|
| [00-PRD](docs/00-产品需求文档-PRD.md) | 产品定位、功能需求、验收标准 |
| [01-架构](docs/01-系统架构设计.md) | 总体架构、技术选型、目录结构 |
| [02-数据模型](docs/02-数据模型设计.md) | 表结构、统一活动模型、迁移策略 |
| [03-API](docs/03-API接口规范.md) | 全部 REST 端点与错误约定 |
| [04-算法](docs/04-训练计划算法.md) | VDOT、配速区间、周期化、自适应 |
| [05-平台接入](docs/05-第三方平台接入.md) | 高驰 OAuth、文件导入、佳明/华为预留 |
| [06-UI规范](docs/06-UI-UX设计规范.md) | 视觉系统、响应式断点、页面体验 |
| [07-路线图](docs/07-路线图与安全.md) | 迭代计划、生产化、安全合规 |

## 快速开始

### 后端（无需 npm install，Node ≥ 22）

```bash
node server/src/index.js        # http://localhost:8080
node --test server/test/        # 冒烟测试
```

可选环境变量：`PORT` `DB_PATH` `JWT_SECRET` `TOKEN_SECRET` `COROS_CLIENT_ID` `COROS_CLIENT_SECRET` `COROS_REDIRECT_URI`

### 客户端（需 Flutter SDK 3.x）

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE=http://localhost:8080/api/v1
```

## 当前状态：v0.1 MVP

- ✅ 方案文档全套
- ✅ 后端：认证 / 档案 / 活动 / GPX 导入 / Mock 同步 / 高驰 OAuth 链路 / 计划引擎 / 统计
- ✅ 客户端：全页面源码（自适应三断点）
- ⏳ 佳明 / 华为官方 API：架构预留，下一迭代
