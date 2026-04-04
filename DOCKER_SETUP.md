# Docker Compose 配置说明

## 🐳 什么是 Docker Compose？

Docker Compose 是一个**容器编排工具**，让你用**一个配置文件**定义和运行**多个相互依赖的容器**。

### 解决的问题

| 场景 | 没有 Compose | 有 Compose |
|------|-------------|-----------|
| 启动应用 | 手动启动 Postgres、Redis、Flask | `docker-compose up` |
| 网络配置 | 手动创建网络、分配 IP | 自动创建内部 DNS |
| 服务发现 | 硬编码 IP 地址 | 服务名 = 主机名 |
| 水平扩展 | 手动复制配置 | `--scale app=5` |

### 核心概念

```
docker-compose.yml 定义：
├── Services (服务): 运行什么容器
├── Networks (网络): 容器间如何通信  
├── Volumes (卷): 数据持久化
└── Dependencies (依赖): 启动顺序
```

---

## 📁 配置文件说明

### `docker-compose.yml` - 主配置

包含以下服务：

```
┌─────────────────────────────────────────────────┐
│                 Nginx (Port 80)                  │
│              Load Balancer                       │
│         Distributes traffic to apps              │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
┌──────────────┐   ┌──────────────┐
│   App 1      │   │   App 2      │
│  Flask       │   │  Flask       │
│  (Scaleable) │   │  (Scaleable) │
└──────┬───────┘   └──────┬───────┘
       │                  │
       └────────┬─────────┘
                ↓
┌─────────────────────────────────────────────────┐
│  Redis (Port 6379)    │  Postgres (Port 5432)  │
│  Cache Layer          │  Database              │
└───────────────────────┴─────────────────────────┘
```

### 服务详解

| 服务 | 功能 | 端口 | Quest 用途 |
|------|------|------|-----------|
| `app` | Flask 应用 | 内部 5000 | 核心业务逻辑 |
| `nginx` | 负载均衡器 | 80 | Silver: 水平扩展 |
| `redis` | 缓存数据库 | 6379 | Gold: 缓存加速 |
| `postgres` | PostgreSQL | 5432 | 数据持久化 |
| `prometheus` | 指标收集 | 9090 | Incident: 监控 |
| `grafana` | 可视化仪表板 | 3000 | Incident: 告警 |
| `alertmanager` | 告警路由 | 9093 | Incident: 通知 |

---

## 🚀 快速开始

### 1. 构建镜像

```bash
make docker-build
```

### 2. 启动基础服务（1个应用实例）

```bash
make docker-up
# 或
docker-compose up -d
```

### 3. 水平扩展（Silver Quest）

```bash
# 启动3个应用实例
make docker-up-3
# 或
docker-compose up -d --scale app=3

# 查看运行状态
make docker-ps
```

### 4. 启动监控（Incident Response Quest）

```bash
make monitor-up
```

访问：
- 应用: http://localhost/health
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### 5. 负载测试（Scalability Quest）

```bash
# Bronze: 50用户
make load-test-bronze

# Silver: 200用户（需要 docker-up-3）
make docker-up-3
make load-test-silver

# Gold: 500用户（需要 docker-up-5 + Redis）
make docker-up-5
make load-test-gold
```

---

## 📊 Scalability Quest 升级路径

### Bronze Tier (50用户)

```bash
# 单实例即可
docker-compose up -d app postgres

# 测试
k6 run --vus 50 --duration 60s tests/load_test_simple.js
```

### Silver Tier (200用户)

```bash
# 3个实例 + Nginx 负载均衡
docker-compose up -d --scale app=3

# 测试
k6 run --vus 200 --duration 120s tests/load_test_simple.js
```

### Gold Tier (500用户)

```bash
# 5个实例 + Nginx + Redis 缓存
docker-compose up -d --scale app=5

# 测试
k6 run --vus 500 --duration 180s tests/load_test_simple.js
```

**预期结果：**
- 95% 请求响应时间 < 3秒
- 错误率 < 5%

---

## 🔧 常用命令

```bash
# 查看所有命令
make help

# 查看日志
make docker-logs
docker-compose logs -f [service_name]

# 扩展服务实例
docker-compose up -d --scale app=4

# 停止所有服务
make docker-down

# 重启单个服务
docker-compose restart app

# 进入容器调试
docker-compose exec app bash

# 查看资源使用
docker stats
```

---

## 🌐 网络架构

Docker Compose 自动创建3个隔离网络：

```
┌─────────────────────────────────────────────────────────┐
│                      frontend                           │
│  User → Nginx:80                                        │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                      backend                            │
│  Nginx → App:5000 → Redis:6379                          │
│              ↓                                          │
│         Postgres:5432                                   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                     monitoring                          │
│  Prometheus:9090 → Grafana:3000                         │
│  Prometheus → Alertmanager:9093                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📝 自定义配置

### 修改环境变量

编辑 `docker-compose.yml` 中的 `environment` 部分：

```yaml
services:
  app:
    environment:
      - DATABASE_PASSWORD=your_password
      - REDIS_HOST=custom-redis
```

### 添加更多应用实例

```bash
docker-compose up -d --scale app=10
```

Nginx 会自动负载均衡到所有实例（通过 Docker 内置 DNS）。

---

## ❓ 常见问题

**Q: 如何查看应用是否正常运行？**
```bash
curl http://localhost/health
```

**Q: 数据库数据会丢失吗？**
不会，使用 `volumes` 持久化到宿主机。

**Q: 如何更新代码？**
```bash
# 修改代码后重新构建
docker-compose build app
docker-compose up -d
```

**Q: Redis 缓存怎么工作？**
应用在 `GET /<short_code>` 时先查 Redis，未命中再查 Postgres。

---

## 🎯 Quest 检查清单

- [ ] Bronze: `make docker-up` + `make load-test-bronze` 通过
- [ ] Silver: `make docker-up-3` + `make load-test-silver` 通过
- [ ] Gold: `make docker-up-5` + `make load-test-gold` 通过
- [ ] Incident Bronze: `make monitor-up` 后访问 Grafana
- [ ] Incident Silver: 配置 Discord Webhook 到 `alertmanager.yml`
- [ ] Incident Gold: 创建 Dashboard 展示 4+ 指标
