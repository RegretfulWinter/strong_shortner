# Git Branching Strategy for PE Hackathon

## 🌳 分支结构

```
main (production-ready)
├── quest/reliability-bronze
├── quest/reliability-silver
├── quest/reliability-gold
├── quest/scalability-bronze
├── quest/scalability-silver
├── quest/scalability-gold
├── quest/incident-bronze
├── quest/incident-silver
└── quest/incident-gold
```

## 🚀 工作流程

### 开始一个 Quest

```bash
# 从 main 创建新分支
git checkout main
git pull origin main
git checkout -b quest/reliability-bronze

# 开发...完成 Bronze
git add .
git commit -m "Complete Reliability Bronze: basic tests and /health endpoint"
git push origin quest/reliability-bronze
```

### 晋级到 Silver

```bash
# 在 Bronze 基础上继续开发
git checkout quest/reliability-bronze
git checkout -b quest/reliability-silver

# 开发...完成 Silver
git add .
git commit -m "Complete Reliability Silver: 50% coverage and CI/CD"
git push origin quest/reliability-silver
```

### 合并到 Main

```bash
# 创建 PR (通过 GitHub 网页或 CLI)
gh pr create --base main --head quest/reliability-silver \
  --title "Quest: Reliability Silver" \
  --body "- [x] 50% test coverage\n- [x] GitHub Actions CI\n- [x] Error handling"

# PR 合并后，删除分支
git branch -d quest/reliability-silver
git push origin --delete quest/reliability-silver
```

## 🎯 CI/CD 触发规则

| 分支类型 | 测试 | Docker构建 | Quest检查 | 部署 |
|---------|------|-----------|----------|------|
| `feature/*` | ✅ | ❌ | ❌ | ❌ |
| `quest/reliability*` | ✅ | ✅ | ✅(Reliability) | ❌ |
| `quest/scalability*` | ✅ | ✅ | ✅(Scalability) | ❌ |
| `quest/incident*` | ✅ | ✅ | ✅(Incident) | ❌ |
| `main` | ✅ | ✅ | ✅(全部) | ✅ |
| PR to main | ✅ | ✅ | ✅(全部) | ❌ |

## 📋 Quest 检查清单

### Reliability Quest
- [ ] Bronze: Basic unit tests, /health endpoint
- [ ] Silver: 50% coverage, GitHub Actions, error handling
- [ ] Gold: 70% coverage, graceful failure, chaos testing

### Scalability Quest
- [ ] Bronze: 50 concurrent users (k6)
- [ ] Silver: 200 users, Docker Compose, Nginx load balancer
- [ ] Gold: 500 users, Redis caching, <5% error rate

### Incident Response Quest
- [ ] Bronze: JSON logs, /metrics endpoint
- [ ] Silver: Alerts (Discord/Slack), <5min notification
- [ ] Gold: Grafana dashboard, Runbook, Golden Signals

## 🔄 日常开发流程

```bash
# 1. 开始工作
git checkout quest/reliability-silver
git pull origin quest/reliability-silver

# 2. 开发功能
git checkout -b feature/add-prometheus-metrics
# ... coding ...
git add .
git commit -m "Add /metrics endpoint for Prometheus"
git push origin feature/add-prometheus-metrics

# 3. 合并到 Quest 分支
gh pr create --base quest/reliability-silver --head feature/add-prometheus-metrics
# PR 合并后
git checkout quest/reliability-silver
git pull origin quest/reliability-silver

# 4. Quest 完成，合并到 main
gh pr create --base main --head quest/reliability-silver
```

## 🏆 提交规范

```
类型: 简短描述

- 类型: feat, fix, test, docs, refactor, perf
- 描述: 做了什么，为什么

Examples:
- "feat: add Redis caching for short URL lookups"
- "test: add integration tests for URL creation"
- "fix: handle duplicate short_code generation"
```
