# `/scripts`

常用开发、构建、安装和运维操作的脚本目录。

---

## 脚本列表

| 脚本 | 说明 | 支持系统 |
|---|---|---|
| [`install-docker.sh`](file:///home/spz/workspace/github/zsp108/Tugboat/scripts/install-docker.sh) | 自动安装 Docker Engine 与 Docker Compose 插件，并将当前用户添加至 docker 组 | Ubuntu / Debian |

---

## 本地开发环境初始化指南

### 1. 安装 Docker（仅需执行一次）

如本机尚未安装 Docker 或 Docker Compose，可执行官方源安装脚本：

```bash
sudo bash scripts/install-docker.sh
```

> **提示**：安装完成后，脚本会将当前用户加入 `docker` 用户组。若要使免 `sudo` 立即生效，请执行 `newgrp docker` 或重新登录终端。

### 2. 准备环境变量

复制 Docker Compose 的环境变量模板：

```bash
cp deployments/docker/.env.example deployments/docker/.env
```

按需编辑 `deployments/docker/.env` 修改数据库密码或端口映射。

### 3. 启动开发依赖服务

启动 PostgreSQL 17（集成 pgvector）以及 MinIO 对象存储：

```bash
docker compose -f deployments/docker/docker-compose.dev.yml up -d
```

#### 服务地址与控制台

| 服务 | 类型 | 地址 / 端口 | 默认凭据 |
|---|---|---|---|
| **PostgreSQL** | 关系型数据库 + pgvector | `localhost:5432` | 用户: `tugboat` / 密码: `tugboat_secret` / 库名: `tugboat` |
| **MinIO API** | S3 对象存储接口 | `http://localhost:9000` | AccessKey: `minioadmin` / SecretKey: `minioadmin_secret` |
| **MinIO Console** | Web 控制台界面 | `http://localhost:9001` | 同上 |

### 4. 停止与清理服务

- **停止容器（保留数据）**：
  ```bash
  docker compose -f deployments/docker/docker-compose.dev.yml down
  ```

- **停止容器并清空所有数据卷（重建全新环境）**：
  ```bash
  docker compose -f deployments/docker/docker-compose.dev.yml down -v
  ```
