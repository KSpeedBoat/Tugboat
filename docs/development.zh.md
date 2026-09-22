# Tugboat 开发文档

## 项目概述

Tugboat 是一个自动化运维平台，后端使用 Go 编写，前端使用 Vue 3。
项目由三个可执行文件组成，协同工作：

| 组件 | 二进制名 | 职责 |
|---|---|---|
| 服务端 | `tugboat-server` | 核心管理服务，提供 REST API 和 Web UI 后端 |
| Agent | `tugboat-agent` | 部署在被监控主机上，执行巡检和故障恢复 |
| CLI | `tugboat` | 管理员客户端，用于平台管理和服务端配置 |

### 组件通信关系

```
tugboat (CLI)
  │
  ├── 本地模式  →  直接操作系统进程（启动/停止/重启）
  └── 远程模式  →  REST API  ──→  tugboat-server
                                        │
                              gRPC  ────┤
                                        │
                                   tugboat-agent（部署在被监控主机）

Web 浏览器  →  REST API  ──→  tugboat-server
```

- **CLI ↔ Server**：HTTP REST API
- **Server ↔ Agent**：gRPC（protobuf）
- **浏览器 ↔ Server**：HTTP REST API

---

## 仓库目录总览

```
Tugboat/
├── cmd/                    # 各二进制的入口
├── internal/               # 私有应用代码（不对外暴露）
├── pkg/                    # 可共享的公共库
├── api/                    # 协议定义
├── web/                    # Vue 3 前端源码
├── configs/                # 配置文件模板
├── deployments/            # 部署相关文件
├── scripts/                # 构建与维护脚本
├── test/                   # 集成测试与 E2E 测试
├── docs/                   # 项目文档
└── tools/                  # 开发工具
```

---

## 目录详细说明

### `cmd/`

各二进制的程序入口。每个子目录只包含一个 `main.go`，负责依赖注入和启动程序。
**业务逻辑不允许写在此处。**

| 目录 | 二进制 | 说明 |
|---|---|---|
| `cmd/tugboat-server/` | `tugboat-server` | 服务端入口 |
| `cmd/tugboat-agent/` | `tugboat-agent` | Agent 入口 |
| `cmd/tugboat/` | `tugboat` | CLI 入口 |

---

### `internal/`

应用私有代码，**不可被外部项目导入**。按组件划分。

#### `internal/server/`

服务端全部逻辑。

| 目录 | 说明 |
|---|---|
| `api/v1/` | REST API v1 路由的 HTTP Handler 函数 |
| `api/middleware/` | HTTP 中间件：身份认证、限流、CORS、日志记录 |
| `service/agent/` | Agent 注册、心跳维护、上下线检测 |
| `service/inspect/` | 巡检任务创建、下发给 Agent、结果采集 |
| `service/recovery/` | 故障恢复策略管理与执行追踪 |
| `service/alert/` | 告警规则评估、去重、通知下发 |
| `service/logquery/` | 跨 Agent 日志查询与聚合 |
| `service/ai/` | AI 模型集成：发送诊断上下文、解析响应结果 |
| `service/scheduler/` | Cron 风格的定时任务调度引擎 |
| `service/config/` | 平台配置管理（AI 提供商、通知渠道等） |
| `repository/agent/` | Agent 数据的数据库访问层 |
| `repository/inspect/` | 巡检结果的数据库访问层 |
| `repository/alert/` | 告警规则与历史的数据库访问层 |
| `repository/log/` | 日志条目的数据库访问层 |
| `grpc/` | 接收 Agent 上报的 gRPC 服务端实现 |

#### `internal/agent/`

Agent 全部逻辑，运行在被监控主机上。

| 目录 | 说明 |
|---|---|
| `inspect/system/` | 系统级巡检：CPU、内存、磁盘、进程健康状态 |
| `inspect/database/` | 数据库巡检：MySQL、PostgreSQL、Redis 连接和指标检查 |
| `recovery/` | 本地故障自愈执行器（如重启服务、清理磁盘空间） |
| `logquery/` | 日志文件采集和关键词模式分析 |
| `reporter/` | gRPC 客户端，将结果和指标上报给服务端 |
| `runner/` | 任务执行器，接收并分发服务端下发的任务 |

#### `internal/cli/`

CLI 命令实现，按操作模式分为本地和远程两类。

| 目录 | 说明 |
|---|---|
| `local/platform/` | 平台进程管理：启动、停止、重启 server 和 web 服务 |
| `local/selfcheck/` | 平台健康检测：验证 server、web、数据库是否正常运行 |
| `local/selfrepair/` | 根据自检结果自动修复平台故障 |
| `remote/config/` | 管理服务端配置的命令（AI 模型、通知渠道） |
| `remote/task/` | 管理巡检与恢复任务模板的命令 |
| `remote/schedule/` | 管理定时任务规则的命令 |
| `remote/alert/` | 管理告警规则的命令 |
| `remote/agent/` | 查看 Agent 列表与状态的命令（只读） |
| `remote/log/` | 从服务端查询日志的命令 |
| `client/` | HTTP 客户端封装，供所有 `remote/` 命令调用服务端 REST API 使用 |

---

### `pkg/`

可被多个内部包共享的公共库，未来也可被外部项目导入。

| 目录 | 说明 |
|---|---|
| `models/` | 共享数据结构：`Agent`、`Task`、`InspectResult`、`Alert`、`LogEntry` 等 |
| `proto/` | 由 `.proto` 文件生成的 Go 代码（**不要手动编辑**） |
| `utils/` | 通用工具函数：加密、时间格式化、HTTP 辅助函数等 |

---

### `api/`

协议和 API 定义，是所有接口的单一事实来源。

| 目录 | 说明 |
|---|---|
| `proto/` | 定义 server 与 agent gRPC 接口的 Protobuf `.proto` 源文件 |
| `openapi/` | REST API 的 OpenAPI（Swagger）YAML/JSON 定义 |

> 修改 `.proto` 文件后，使用 `tools/` 中的脚本将 Go 代码重新生成到 `pkg/proto/`。

---

### `web/`

Vue 3 前端应用。

| 目录 | 说明 |
|---|---|
| `src/views/Dashboard/` | 总览仪表盘：Agent 数量、近期告警、巡检概况 |
| `src/views/Agents/` | Agent 列表与单个 Agent 详情 |
| `src/views/Inspect/` | 巡检任务管理与结果浏览 |
| `src/views/Recovery/` | 故障恢复历史记录与手动触发 |
| `src/views/Alert/` | 告警规则配置与告警历史 |
| `src/views/Log/` | 日志查询界面 |
| `src/views/Settings/` | 平台设置：AI 模型、通知渠道、调度规则 |
| `src/components/` | 可复用 UI 组件 |
| `src/api/` | 前端 API 调用封装（与服务端 REST API 对应） |
| `src/store/` | 基于 Pinia 的全局状态管理 |
| `public/` | 原样输出的静态资源（favicon、字体等） |

---

### `configs/`

各组件的配置文件模板，复制后重命名即可使用：

| 文件 | 说明 |
|---|---|
| `server.yaml.example` | 服务端配置模板（数据库、gRPC 端口、JWT 密钥、AI 提供商等） |
| `agent.yaml.example` | Agent 配置模板（服务端地址、巡检间隔等） |

---

### `deployments/`

部署相关文件，运行时不使用。

| 目录 | 说明 |
|---|---|
| `docker/` | 各二进制的 `Dockerfile` 及本地开发用 `docker-compose.yml` |
| `systemd/` | 用于将 server 和 agent 注册为 Linux 系统服务的 systemd unit 文件 |
| `kubernetes/` | 容器化部署的 Kubernetes manifests（可选） |

---

### `scripts/`

常用开发和运维操作的 Shell 脚本：

| 脚本 | 说明 |
|---|---|
| `build.sh` | 编译全部三个二进制 |
| `release.sh` | 打标签并构建发布产物 |
| `migrate.sh` | 执行数据库 Schema 迁移 |

---

### `test/`

需要运行环境支持的集成测试和端到端测试。
单元测试放在对应源文件旁边（如 `foo_test.go` 与 `foo.go` 同目录）。

---

### `tools/`

开发时使用的工具和代码生成辅助脚本：

- Proto 代码生成脚本（`generate_proto.sh`）
- 单元测试 Mock 生成
- 其他构建时工具

---

## 开发规范

### Commit 信息

遵循 [Angular Commit 规范](https://github.com/zsp108/dev_scripts/blob/develop/docs/git-commit-guide.md)，使用英文书写。

```
<type>(<scope>): <简短描述>

[可选 body]

[可选 footer]
```

常用类型：`feat`、`fix`、`refactor`、`docs`、`chore`、`test`、`ci`、`perf`、`style`

### 分支策略

| 分支 | 用途 |
|---|---|
| `main` | 稳定发布分支 |
| `devloop` | 主开发分支 |
| `feat/<name>` | 功能分支，合并到 `devloop` |
| `fix/<name>` | Bug 修复分支 |

### Module 路径

```
github.com/KSpeedBoat/Tugboat
```

### 新功能开发流程

1. 从 `devloop` 创建功能分支：`git checkout -b feat/<name>`
2. 如需新数据结构，在 `pkg/models/` 中添加
3. 在 `internal/server/repository/<domain>/` 中添加数据库访问方法
4. 在 `internal/server/service/<domain>/` 中实现业务逻辑
5. 在 `internal/server/api/v1/` 中添加 HTTP Handler 暴露接口
6. 如涉及 Agent，更新 `api/proto/` 中的 proto 文件，重新生成 `pkg/proto/`
7. 在 `internal/cli/remote/<domain>/` 中添加对应 CLI 命令
8. 在 `web/src/views/` 中添加对应的 Web UI 页面或组件
9. 在源文件旁编写单元测试
10. 按规范提交，向 `devloop` 发起 PR
