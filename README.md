# URL Shortener - Meta PE Hackathon

A production-ready URL shortener service built for the Meta Production Engineering Hackathon. This project demonstrates reliability, scalability, and incident response best practices.

[![Python 3.13+](https://img.shields.io/badge/python-3.13+-blue.svg)](https://www.python.org/downloads/)
[![Flask](https://img.shields.io/badge/flask-3.1+-green.svg)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 📋 Table of Contents

- [Quick Start](#-quick-start) - Get running in 5 minutes
- [Architecture](#-architecture) - System design & diagrams
- [API Documentation](#-api-documentation) - All endpoints
- [Deployment Guide](#-deployment-guide) - Production setup
- [Environment Variables](#-environment-variables) - Configuration
- [Monitoring](#-monitoring) - Observability stack
- [Troubleshooting](#-troubleshooting) - Common issues
- [Decision Log](#-decision-log) - Technical choices
- [Capacity Planning](#-capacity-planning) - Performance limits

---

## 🚀 Quick Start

**Prerequisites:** Docker and Docker Compose installed

```bash
# 1. Clone and enter directory
git clone https://github.com/RegretfulWinter/strong_shortner.git
cd strong_shortner

# 2. Start all services
docker compose up -d

# 3. Verify health
curl http://localhost/health
# Expected: {"status": "ok", ...}

# 4. Test API
curl -X POST http://localhost/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://example.com", "title": "Example"}'
```

**Services will be available at:**
- API: http://localhost (Nginx Load Balancer)
- Grafana: http://localhost:3000 (admin/admin123)
- Prometheus: http://localhost:9090
- PostgreSQL: localhost:5433

---

## 🏗️ Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Nginx (Port 80)                          │
│                    Load Balancer (least_conn)                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   App 1      │ │   App 2      │ │   App 3      │
│   Flask      │ │   Flask      │ │   Flask      │
│   Gunicorn   │ │   Gunicorn   │ │   Gunicorn   │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       └────────────────┼─────────────────┘
                        │
       ┌────────────────┴────────────────┐
       │                                   │
┌──────▼───────┐                 ┌────────▼─────┐
│   Redis      │                 │  PostgreSQL  │
│   (Port 6379)│                 │  (Port 5432) │
│   Cache      │                 │  Database    │
└──────────────┘                 └──────────────┘
```

### Data Flow

1. **Client Request** → Nginx (Load Balancer)
2. **Nginx** → Routes to App 1/2/3 (Round-robin with least_conn)
3. **App** → Queries PostgreSQL for persistence
4. **App** → Uses Redis for caching (optional)
5. **Response** → Returns to client

### Monitoring Stack

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Prometheus  │◄───│   App 1/2/3 │    │  Grafana    │
│ (Metrics)   │    │  (/metrics) │───►│ (Dashboard) │
└─────────────┘    └─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│ Alertmanager│───► Discord/Slack
│ (Alerts)    │
└─────────────┘
```

---

## 📚 API Documentation

### Health & Monitoring

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/health` | Health check for load balancer | `{"status": "ok", "checks": {...}}` |
| `GET` | `/metrics` | Prometheus metrics (JSON for browser) | CPU, RAM, request stats |

### Users

| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| `GET` | `/users` | List all users | - |
| `POST` | `/users` | Create new user | `{"username": "string", "email": "string"}` |
| `GET` | `/users/<id>` | Get user by ID | - |
| `PUT` | `/users/<id>` | Update user | `{"username": "string", "email": "string"}` |
| `DELETE` | `/users/<id>` | Delete user | - |
| `POST` | `/users/bulk` | Bulk import from CSV | `multipart/form-data` with CSV file |

### URLs

| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| `GET` | `/urls` | List all URLs | - |
| `POST` | `/urls` | Create short URL | `{"original_url": "string", "title": "string"}` |
| `GET` | `/urls/<id>` | Get URL by ID | - |
| `PUT` | `/urls/<id>` | Update URL | `{"original_url": "string", "title": "string"}` |
| `DELETE` | `/urls/<id>` | Delete URL | - |
| `GET` | `/<short_code>` | Redirect to original URL | - |

### Events

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/events` | List analytics events |

### Example Requests

```bash
# Health check
curl http://localhost/health

# Create user
curl -X POST http://localhost/users \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "email": "alice@example.com"}'

# Create short URL
curl -X POST http://localhost/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://www.google.com", "title": "Google"}'

# List all URLs
curl http://localhost/urls

# Access short URL (redirects)
curl -L http://localhost/abc123
```

---

## 🚢 Deployment Guide

### Local Development

```bash
# Start with hot-reload for development
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

# View logs
docker compose logs -f app1

# Scale to 3 instances
docker compose up -d --scale app1=1 --scale app2=1 --scale app3=1
```

### Production Deployment

#### Option 1: Docker Compose on VPS

```bash
# 1. Clone on server
git clone https://github.com/RegretfulWinter/strong_shortner.git
cd strong_shortner

# 2. Set environment variables
export DATABASE_HOST=your-db-host
export DATABASE_PASSWORD=your-secure-password
export REDIS_HOST=your-redis-host

# 3. Start services
docker compose up -d

# 4. Verify
curl http://your-server-ip/health
```

#### Option 2: Manual Deployment Steps

```bash
# Build image
docker build -t url-shortener:latest .

# Run with custom config
docker run -d \
  -e DATABASE_HOST=postgres \
  -e DATABASE_PASSWORD=secret \
  -p 5000:5000 \
  url-shortener:latest
```

### Rollback Procedure

```bash
# Check previous working image
docker images url-shortener

# Rollback to previous version
docker compose down
docker tag url-shortener:<previous-tag> url-shortener:latest
docker compose up -d

# Or use git tag
git log --oneline
git checkout <previous-commit>
docker compose up -d --build
```

---

## 🔧 Environment Variables

### Required

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_HOST` | PostgreSQL host | `postgres` |
| `DATABASE_NAME` | Database name | `hackathon_db` |
| `DATABASE_USER` | Database user | `postgres` |
| `DATABASE_PASSWORD` | Database password | `postgres` |
| `DATABASE_PORT` | Database port | `5432` |
| `REDIS_HOST` | Redis host | `redis` |
| `REDIS_PORT` | Redis port | `6379` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `FLASK_ENV` | Environment mode | `production` |
| `INSTANCE_ID` | Instance identifier | `app` |
| `API_KEY` | API authentication key | - |

### Example .env File

```bash
# Database
DATABASE_HOST=localhost
DATABASE_NAME=hackathon_db
DATABASE_USER=postgres
DATABASE_PASSWORD=your-secure-password
DATABASE_PORT=5432

# Cache
REDIS_HOST=localhost
REDIS_PORT=6379

# App
FLASK_ENV=production
```

---

## 📊 Monitoring

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin123 |
| Prometheus | http://localhost:9090 | - |
| Alertmanager | http://localhost:9093 | - |

### Key Metrics

- **HTTP Request Rate**: `rate(flask_http_request_total[1m])`
- **Error Rate**: `rate(flask_http_request_total{status=~"5.."}[5m])`
- **P95 Latency**: `histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))`
- **CPU Usage**: `rate(process_cpu_seconds_total[1m])`
- **Memory Usage**: `process_resident_memory_bytes`

### JSON Logs

Structured logging format:
```json
{
  "timestamp": "2026-04-05T16:27:09.376315+00:00",
  "level": "INFO",
  "component": "DB",
  "msg": "Database tables initialized",
  "function": "init_db"
}
```

View logs:
```bash
docker logs <container-name> | grep "^{"
```

---

## 🔍 Troubleshooting

### Common Issues

#### Issue: "Connection refused" to database

**Symptoms**: App fails to start, logs show PostgreSQL connection errors

**Solution**:
```bash
# Check if PostgreSQL is running
docker compose ps

# Check logs
docker compose logs postgres

# Restart database
docker compose restart postgres

# Verify connection from app container
docker compose exec app1 pg_isready -h postgres
```

#### Issue: 503 Service Unavailable from Nginx

**Symptoms**: curl returns `{"error": "Service Unavailable"}`

**Solution**:
```bash
# Check if app containers are healthy
docker compose ps

# Check app logs
docker compose logs app1

# Restart apps
docker compose restart app1 app2 app3
```

#### Issue: Prometheus metrics not showing

**Symptoms**: /metrics endpoint returns error

**Solution**:
```bash
# Check if metrics endpoint works directly
curl http://localhost:5000/metrics

# Restart Prometheus
docker compose restart prometheus
```

#### Issue: Tests fail with "Duplicated timeseries"

**Symptoms**: `ValueError: Duplicated timeseries in CollectorRegistry`

**Cause**: Prometheus metrics registered multiple times in test environment

**Solution**: Already fixed in code with try/except blocks. Update to latest version:
```bash
git pull origin main
```

### Debug Mode

```bash
# Enable Flask debug mode (NOT for production)
export FLASK_ENV=development

# Run with verbose logging
docker compose logs -f

# Check specific container
docker exec -it <container-name> /bin/sh
```

---

## 🧠 Decision Log

### Why Flask + Gunicorn?

**Decision**: Use Flask with Gunicorn WSGI server

**Rationale**:
- Flask: Lightweight, easy to understand, well-documented
- Gunicorn: Production-ready, handles multiple workers, battle-tested
- Alternative considered: FastAPI - faster but adds complexity

**Trade-off**: Simplicity over raw performance

### Why PostgreSQL?

**Decision**: Use PostgreSQL as primary database

**Rationale**:
- ACID compliance for data integrity
- Excellent Peewee ORM support
- Reliability and data durability
- Alternative considered: SQLite (not suitable for concurrent access)

### Why Redis?

**Decision**: Add Redis for caching layer

**Rationale**:
- Fast in-memory storage for frequently accessed data
- Session storage capability
- Rate limiting support
- Alternative considered: Memcached (Redis has more features)

**Status**: Infrastructure ready, caching implementation pending Gold tier

### Why Nginx as Load Balancer?

**Decision**: Use Nginx for load balancing

**Rationale**:
- Industry standard reverse proxy
- Excellent performance and stability
- Built-in health checks
- Rate limiting capabilities
- Alternative considered: HAProxy (Nginx has better ecosystem)

### Why Docker Compose?

**Decision**: Use Docker Compose for orchestration

**Rationale**:
- Simple declarative configuration
- Easy local development
- Portable across environments
- Alternative considered: Kubernetes (overkill for this scale)

### Why Prometheus + Grafana?

**Decision**: Use Prometheus for metrics, Grafana for visualization

**Rationale**:
- Open source, widely adopted
- Excellent Flask integration
- Powerful query language (PromQL)
- Rich visualization capabilities
- Alternative considered: Datadog (paid, vendor lock-in)

---

## 📈 Capacity Planning

### Current Limits

| Metric | Bronze | Silver | Gold (Target) |
|--------|--------|--------|---------------|
| Concurrent Users | 50 | 200 | 500+ |
| Response Time (P95) | <500ms | <3s | <1s |
| Error Rate | <10% | <5% | <1% |
| Instances | 1 | 3 | 3+ (auto-scale) |

### Resource Allocation

Per App Instance:
- CPU: 0.5 cores
- Memory: 256 MB
- Workers: 4 (Gunicorn)

### Bottlenecks

1. **Database**: PostgreSQL connection pool (current: default)
2. **Network**: Nginx worker connections (current: 1024)
3. **Memory**: Per-instance limit may need increase under high load

### Scaling Strategy

**Horizontal Scaling** (Preferred):
- Add more app instances behind Nginx
- Share PostgreSQL and Redis
- Stateless application design

**Vertical Scaling** (When needed):
- Increase CPU/memory per instance
- Optimize database queries
- Add Redis caching

### Performance Test Results

**Scalability Silver - 200 Concurrent Users**:
```
Total Requests:    200
Successful:        200
Error Rate:        0%
P95 Latency:       1092ms (< 3000ms baseline)
Throughput:        100 req/sec
```

---

## 🏆 Quest Progress

- [x] **Reliability Bronze** - Basic tests, `/health` endpoint
- [x] **Reliability Silver** - 50% coverage, GitHub Actions CI
- [x] **Reliability Gold** - 70% coverage, graceful failure, chaos mode
- [x] **Scalability Bronze** - 50 concurrent users (k6)
- [x] **Scalability Silver** - 200 users, 3 containers, Nginx
- [ ] **Scalability Gold** - 500 users, Redis caching, auto-scaling
- [x] **Incident Bronze** - JSON logs, `/metrics` endpoint
- [ ] **Incident Silver** - Alerts to Discord, <5min notification
- [ ] **Incident Gold** - Runbooks, Golden Signals

---

## 📁 Project Structure

```
.
├── app/                      # Flask application
│   ├── __init__.py          # App factory
│   ├── database.py          # Database setup
│   ├── logging_config.py    # JSON logging
│   ├── models/              # Peewee models
│   ├── routes/              # API endpoints
│   └── static/              # Frontend files
├── docs/                    # Documentation
├── monitoring/              # Grafana, Prometheus configs
├── scripts/                 # Load tests, utility scripts
├── tests/                   # pytest test suite
├── docker-compose.yml       # Main orchestration
├── Dockerfile               # App container
└── README.md                # This file
```

---

## 📜 License

MIT License - Meta PE Hackathon 2026

---

**Last Updated**: April 6, 2026  
**Version**: 1.0.0  
**Maintainer**: RegretfulWinter
