# `/scripts`

常用开发、构建、安装和运维操作的脚本目录。

---

## 脚本列表

| 脚本 | 说明 | 支持系统 |
|---|---|---|
| [`docker_install.sh`](file:///home/spz/workspace/github/zsp108/Tugboat/scripts/docker_install.sh) | 自动安装与卸载 Docker 及 Docker Compose 插件，支持自定义版本、仓库通道、存储路径与用户组授权 | Ubuntu / Debian / RHEL / CentOS / Rocky / Fedora |

---

## 本地开发环境初始化指南

### 1. 安装 Docker（仅需执行一次）

如本机尚未安装 Docker，可直接执行安装脚本：

```bash
# 默认安装最新稳定版，存储路径为 /var/lib/docker
sudo bash scripts/docker_install.sh

# 可选：指定版本、通道与数据目录
# sudo bash scripts/docker_install.sh 27.2.0 stable /data/docker
```

> **提示**：安装完成后脚本会自动将当前用户加入 `docker` 组。若要使免 `sudo` 立即生效，请执行 `newgrp docker` 或重新登录终端。

#### 卸载 Docker（如需彻底重置环境）

```bash
# 仅卸载 Docker 软件，保留容器数据
sudo bash scripts/docker_install.sh uninstall

# 彻底卸载并清理所有容器、镜像和数据卷
sudo bash scripts/docker_install.sh uninstall --purge-data
```

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
