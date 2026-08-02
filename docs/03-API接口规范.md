# API 接口规范 v1

- Base URL：`http://localhost:8080/api/v1`
- 认证：`Authorization: Bearer <accessToken>`（登录/注册/刷新除外）
- 内容：`application/json; charset=utf-8`
- 时间：epoch 毫秒（UTC）；配速：秒/公里；距离：米

## 错误约定

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": {} } }
```

| HTTP | code | 场景 |
|---|---|---|
| 400 | VALIDATION_ERROR | 参数非法 |
| 401 | UNAUTHORIZED / TOKEN_EXPIRED | 未登录 / 令牌过期 |
| 403 | FORBIDDEN | 无权限 |
| 404 | NOT_FOUND | 资源不存在 |
| 409 | CONFLICT | 邮箱已注册等冲突 |
| 502 | UPSTREAM_ERROR | 第三方平台调用失败 |
| 500 | INTERNAL_ERROR | 服务端错误 |

## 1. 认证 Auth

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | /auth/register | `{email, password, nickname?}` → `{user, tokens}` |
| POST | /auth/login | `{email, password}` → `{user, tokens}` |
| POST | /auth/refresh | `{refreshToken}` → `{tokens}`（旋转刷新令牌） |
| POST | /auth/logout | 吊销刷新令牌 |
| GET | /auth/me | 当前用户 + 档案 |

`tokens = { accessToken(15min), refreshToken(30d), expiresIn }`

## 2. 档案 Profile

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /profile | 查询档案（含心率区间） |
| PUT | /profile | 全量更新档案字段；心率区间自动重算 |
| GET | /profile/zones | 心率区间 + 各区间定义 |

请求体字段见 `02-数据模型设计.md#profiles`（camelCase）。

## 3. 活动 Activities

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /activities?from=&to=&page=&pageSize= | 分页列表（时间倒序） |
| GET | /activities/:id | 详情（含 laps/streams） |
| POST | /activities | 手动录入 |
| DELETE | /activities/:id | 删除 |
| POST | /activities/import | 文件导入：`{filename, contentBase64}`（GPX） |

## 4. 同步 Sync

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /sync/providers | 可用 Provider 列表及能力/配置状态 |
| GET | /sync/connections | 我的连接列表 |
| POST | /sync/connections | 建立连接 `{provider, ...}`（mock 直连；coros 返回授权 URL） |
| GET | /sync/connections/coros/authorize-url | 生成高驰 OAuth 授权链接 |
| GET | /sync/callback/coros?code=&state= | 高驰 OAuth 回调（换令牌、建连接） |
| DELETE | /sync/connections/:id | 断开连接 |
| POST | /sync/connections/:id/sync | 触发同步 → `{jobId, added, skipped}` |
| GET | /sync/jobs?limit= | 同步历史 |

## 5. 训练计划 Plans

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /plans/options | 目标类型、课型、默认参数说明 |
| POST | /plans/preview | 参数试算：返回 VDOT、配速区、周概览（不落库） |
| POST | /plans | 生成并保存计划（同 preview 参数 + name） |
| GET | /plans | 计划列表 |
| GET | /plans/:id | 计划详情（含全部课表） |
| POST | /plans/:id/workouts/:workoutId/status | 标记 done/skipped，可关联 activityId |
| POST | /plans/:id/adapt | 基于近 2 周完成度给出调整建议/重算后续 |
| DELETE | /plans/:id | 归档 |

**preview/创建参数**：
```json
{
  "raceType": "full",
  "goalTimeSec": 14400,
  "weeks": 18,
  "sessionsPerWeek": 4,
  "vdot": 45.2,
  "startDate": "2026-08-10"
}
```
说明：`raceType`: 5k|10k|half|full；`goalTimeSec` 可空=完赛；`weeks` 或与 `raceDate` 二选一；`vdot` 可空 → 由 PB/近期数据推断；`startDate` 可空 → 下周一。

## 6. 统计 Stats

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /stats/dashboard | 本周跑量、计划完成度、ATL/CTL/TSB、最近活动 |
| GET | /stats/weekly?weeks=12 | 周跑量/次数/均配速 |
| GET | /stats/hr-distribution?from=&to= | 心率区间时间分布 |

## 7. 系统

| GET /health | 存活检查 `{status:"ok", version}` |

## 分页约定

`{ items: [...], page, pageSize, total }`，默认 page=1, pageSize=20, 最大 100。
