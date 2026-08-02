# PaceForge — 马拉松训练客户端（Flutter）

面向严肃跑者的一站式马拉松训练 App：多平台数据汇聚（高驰 / GPX 文件 / Mock）、VDOT 周期化训练计划、ATL/CTL/TSB 负荷看板。
设计依据：`docs/01-系统架构设计.md`、`docs/03-API接口规范.md`、`docs/06-UI-UX设计规范.md`、`docs/00-产品需求文档-PRD.md`。

## 环境要求

- Flutter SDK 3.x（稳定版，Dart 3）
- 后端：`node server/src/index.js`（默认 `http://localhost:8080`）

## 快速开始

```bash
cd app
flutter pub get

# 连接本机后端（Android 模拟器请改用 http://10.0.2.2:8080/api/v1）
flutter run

# 指定后端地址
flutter run --dart-define=API_BASE=http://192.168.1.10:8080/api/v1

# 构建
flutter build apk        # Android
flutter build ipa        # iOS（需 macOS + Xcode）
```

## API_BASE 配置

通过编译期常量注入，默认 `http://localhost:8080/api/v1`：

```bash
flutter run --dart-define=API_BASE=http://<host>:8080/api/v1
```

代码位置：`lib/core/api_client.dart`（`String.fromEnvironment('API_BASE', ...)`）。
注意：Android 模拟器访问宿主机需使用 `10.0.2.2`；真机需使用局域网 IP。

## 目录结构（对应架构文档第 4 节）

```
lib/
├── main.dart                  # 入口、依赖注入、主题、RootGate（登录态路由）
├── core/
│   ├── theme.dart             # Material 3 主题、配色（#00D9A6）、课型/阶段/心率区间色
│   ├── responsive.dart        # 断点：<600 / 600–1024 / >1024
│   ├── api_client.dart        # dio 封装、Authorization 拦截、401 刷新重试
│   ├── storage.dart           # shared_preferences（token）
│   └── format.dart            # 配速 5'30" / 时长 1:23:45 / 距离 10.0 km 等
├── models/                    # 手写 fromJson/toJson（无代码生成）
├── providers/                 # ChangeNotifier：auth/profile/activities/plan/stats/sync
├── repositories/              # REST 接口封装（与 docs/03 对齐）
├── services/                  # sync_service（Mock 连接+同步、GPX 导入）、plan_service
└── ui/
    ├── pages/                 # 登录/主框架/仪表盘/计划/活动/我的 等 12 个页面
    └── widgets/               # 图表、课表卡、活动项、区间条等通用组件
```

## 功能清单

- 登录 / 注册（表单校验、错误提示、JWT 自动续期）
- 自适应主框架：compact 底部 NavigationBar / medium NavigationRail / expanded 侧边栏
- 仪表盘：本周跑量、计划完成度、ATL/CTL/TSB 趋势图、今日课表、最近活动
- 计划生成向导（3 步 + /plans/preview 实时 VDOT 与配速区）→ 生成 → 周视图详情
  （阶段色带 + 周跑量柱状 + 课表卡：课型徽章/配速区间/心率区间/标记完成）
- 活动：分页列表（provider 标签）、expanded 双栏、详情（指标网格、配速/心率曲线、圈速表）
- 手动录入、GPX 文件导入（file_picker → base64 → /activities/import）
- 我的：档案编辑（全字段）、心率区间展示、数据连接（高驰 OAuth 跳转 / Mock 一键同步 /
  同步历史 / 断开连接）、设置与退出登录

## 依赖

| 包 | 用途 |
|---|---|
| provider | 状态管理 |
| dio | 网络（拦截器/重试） |
| shared_preferences | token 存储 |
| fl_chart | 负荷趋势 / 配速心率曲线 / 跑量柱状 |
| file_picker | GPX 文件选择 |
| url_launcher | 高驰 OAuth 授权跳转 |
| intl | 日期格式化 |

不使用代码生成（无 build_runner / freezed），模型全部手写。

## 已知限制

- 高驰 OAuth 回调走系统浏览器 → 后端重定向 `paceforge://sync/success`；自定义 scheme
  的深层链接需在各平台原生工程（`android/`、`ios/`）中另行配置，本仓库仅含 Dart 代码，
  授权完成后请在连接页下拉刷新。
- 离线缓存（SQLite）与图表无障碍语义细化在下一迭代；当前网络失败时展示错误与重试。
- 地图轨迹为预留位（PRD 范围外）。
- iOS 首次运行需在 Xcode 中配置签名；`flutter pub get` 前请确认 Flutter 版本 ≥ 3.22。
