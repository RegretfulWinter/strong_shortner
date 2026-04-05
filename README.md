# URL Shortener - Meta PE Hackathon

A production-ready URL shortener service built for the Meta Production Engineering Hackathon.

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Backend** | Flask + Peewee ORM |
| **Database** | PostgreSQL |
| **Cache** | Redis |
| **Load Balancer** | Nginx |
| **Monitoring** | Prometheus + Grafana + Alertmanager |
| **Testing** | pytest + k6 |
| **Package Manager** | uv |
| **Deployment** | Docker + Digital Ocean |

## Project Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Nginx (Port 80)                     │
│                    Load Balancer                        │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   App 1      │ │   App 2      │ │   App N      │
│   Flask      │ │   Flask      │ │   Flask      │
│   Gunicorn   │ │   Gunicorn   │ │   Gunicorn   │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       └────────────────┼─────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Redis (Port 6379)        │  PostgreSQL (Port 5432)    │
│  Cache Layer              │  Primary Database            │
└───────────────────────────┴─────────────────────────────┘
```

## Branching Strategy

We use a **quest-based branching strategy** aligned with the hackathon requirements.

### Branch Structure

```
main (production-ready)
├── quest/reliability-bronze    # Basic tests + /health endpoint
├── quest/reliability-silver    # 50% coverage + CI/CD
├── quest/reliability-gold      # 70% coverage + Chaos testing
├── quest/scalability-bronze    # 50 concurrent users (k6)
├── quest/scalability-silver    # 200 users + Docker + Nginx
├── quest/scalability-gold      # 500 users + Redis + <5% errors
├── quest/incident-bronze       # JSON logs + /metrics endpoint
├── quest/incident-silver       # Alerts (Discord/Slack)
└── quest/incident-gold         # Grafana dashboard + Runbook
```

### Workflow

```bash
# 1. Start a quest branch from main
git checkout main
git pull origin main
git checkout -b quest/reliability-bronze

# 2. Develop and commit
git add .
git commit -m "feat: add basic tests and health endpoint"
git push origin quest/reliability-bronze

# 3. Create PR when quest tier is complete
gh pr create --base main --head quest/reliability-bronze

# 4. After PR merge, delete the branch
git branch -d quest/reliability-bronze
```

### CI/CD Behavior

| Branch | Tests | Docker | Quest Checks | Deploy |
|--------|-------|--------|--------------|--------|
| `quest/*` | ✅ | ✅ | ✅ | ❌ |
| `main` | ✅ | ✅ | ✅ | ✅ |
| PR to main | ✅ | ✅ | ✅ | ❌ |

## Naming Conventions

### Branches

```
quest/<quest-name>-<tier>     # e.g., quest/reliability-bronze
feature/<description>          # e.g., feature/add-redis-cache
fix/<description>              # e.g., fix/duplicate-short-code
```

### Commits

```
<type>: <description>

Types:
  feat     - New feature
  fix      - Bug fix
  test     - Adding tests
  docs     - Documentation
  refactor - Code refactoring
  perf     - Performance improvement

Examples:
  feat: add Redis caching for URL lookups
  test: add k6 load tests for 200 users
  fix: handle duplicate short_code generation
```

### API Endpoints

```
GET  /health              # Health check
GET  /users               # List users
POST /users               # Create user
GET  /users/<id>          # Get user by ID
PUT  /users/<id>          # Update user
POST /users/bulk          # Bulk import from CSV

GET  /urls                # List URLs
POST /urls                # Create short URL
GET  /urls/<id>           # Get URL by ID
PUT  /urls/<id>           # Update URL
GET  /<short_code>        # Redirect to original URL

GET  /events              # List analytics events
GET  /metrics             # Prometheus metrics (Incident Quest)
```

## Quick Start

### Local Development

```bash
# Install dependencies
uv sync

# Start services with Docker
make docker-up

# Initialize database (creates tables only, safe to run multiple times)
docker-compose exec app python init_db.py

# Import seed data (for local testing only)
make import-csv

# Test API
curl http://localhost/health
```

### ⚠️ Hackathon Evaluation Note

> **For hackathon evaluation:** The judges automatically provision a PostgreSQL database with seed data pre-loaded. You **do not** need to import CSV files or seed the database. Your app should start and immediately connect to the existing database with data already present.
>
> The evaluation environment:
> - Starts with a clean container
> - PostgreSQL is pre-configured with seed data
> - No caching between evaluations
> - Tables are already created and populated
>
> Just make sure your app can connect to the database using environment variables.

## Available Make Commands

```bash
make help              # Show all commands

# Development
make docker-up         # Start all services
make docker-down       # Stop all services
make docker-up-3       # Scale to 3 instances

# Testing
make test              # Run pytest
make test-cov          # Run with coverage
make load-test-bronze  # 50 users load test
make load-test-silver  # 200 users load test
make load-test-gold    # 500 users load test

# Monitoring
make monitor-up        # Start Prometheus + Grafana
```

## Quest Progress

- [ ] **Reliability Bronze** - Basic tests, `/health` endpoint
- [ ] **Reliability Silver** - 50% coverage, GitHub Actions CI
- [ ] **Reliability Gold** - 70% coverage, graceful failure, chaos mode
- [ ] **Scalability Bronze** - 50 concurrent users (k6)
- [ ] **Scalability Silver** - 200 users, 2+ containers, Nginx
- [ ] **Scalability Gold** - 500 users, Redis cache, <5% errors
- [ ] **Incident Bronze** - JSON logs, `/metrics` endpoint
- [ ] **Incident Silver** - Alerts to Discord, <5min notification
- [ ] **Incident Gold** - Grafana dashboard, Runbook, Golden Signals

## Documentation

- [Docker Setup](DOCKER_SETUP.md) - Multi-service orchestration
- [Deployment Guide](DEPLOY.md) - Digital Ocean deployment
- [Branching Strategy](BRANCHING.md) - Detailed git workflow

## License

MIT License - Meta PE Hackathon 2026
# Auto deployed to Vultr - Sun Apr  5 16:43:15 CST 2026
