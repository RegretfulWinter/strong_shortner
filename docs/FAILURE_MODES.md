# Failure Modes & Chaos Engineering Documentation

## Overview

This document describes failure scenarios and how the system handles them, following chaos engineering principles.

## Philosophy

> "Chaos Engineering: Don't wait for a crash at 3 AM. Cause the crash at 2 PM and fix it."

**Graceful Failure Principle:**
> "A user should see 'Service Unavailable,' not a Python stack trace."

---

## Failure Mode Matrix

| Component | Failure Mode | Impact | Detection | Recovery | Auto-Restart |
|-----------|--------------|--------|-----------|----------|--------------|
| App Container | Crash/Exit | API unavailable | Health check fails | Docker restart | ✅ Yes |
| Database | Connection lost | All writes fail | Connection timeout | Retry + fail fast | ❌ No (data persistence) |
| Nginx | Crash | External access lost | Health check | Docker restart | ✅ Yes |
| Redis | Unavailable | Cache miss only | Connection error | Fallback to DB | ✅ Yes |

---

## 🔄 Container Auto-Restart (Chaos Mode)

### Configuration

All critical services in `docker-compose.prod.yml` include:

```yaml
services:
  app:
    restart: unless-stopped  # Auto-restart on crash
    
  nginx:
    restart: unless-stopped
    
  postgres:
    restart: unless-stopped
```

**Restart Policy Options:**
- `no`: Never restart (default)
- `always`: Always restart regardless of exit code
- `unless-stopped`: Restart unless manually stopped
- `on-failure`: Restart only on non-zero exit code

**Why `unless-stopped`?**
- Restarts after crashes (non-zero exit)
- Restarts after server reboot
- Allows manual maintenance (docker compose stop)

---

## 🔥 Chaos Testing

### Live Demo 1: Container Auto-Restart

**Script:** `scripts/demo-chaos-mode.sh`

**Steps:**
```bash
# 1. Verify app is healthy
curl http://localhost:80/health
# → {"status": "ok"}

# 2. Kill the container
docker compose kill app

# 3. Wait 5-10 seconds

# 4. Verify auto-restart
curl http://localhost:80/health
# → {"status": "ok"} (again!)
```

**Expected Behavior:**
- Container dies immediately on `kill`
- Docker detects exit
- New container spawned within 5-10 seconds
- Health endpoint responds again
- **Zero manual intervention**

**Production Impact:**
- Downtime: ~5-10 seconds
- No data loss (stateless app)
- No manual recovery needed

---

### Live Demo 2: Graceful Failure

**Script:** `scripts/demo-graceful-failure.sh`

**Test: Invalid JSON**
```bash
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d "not valid json"
```

**❌ Bad Response (Stack Trace):**
```html
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>500 Internal Server Error</title>
... (hundreds of lines of traceback)
```

**✅ Good Response (Our App):**
```json
{
  "error": "Invalid request body"
}
```

**HTTP Status:** 400 (Bad Request)

**Why This Matters:**
- **Security**: Stack traces reveal code structure
- **UX**: Users understand what went wrong
- **API Contract**: Consistent JSON format

---

## 🛡️ Graceful Error Responses

### Scenario 1: Database Unavailable (500)

**Trigger:** PostgreSQL container stopped

**Request:**
```bash
GET /users
```

**Response:**
```json
{
  "error": "Internal server error. Please try again later."
}
```

**Status:** 500

**Logged (Server-side):**
```
ERROR: Database connection failed: connection refused
Traceback: ... (full stack trace for developers)
```

---

### Scenario 2: Invalid Request Body (400)

**Trigger:** Malformed JSON

**Request:**
```bash
POST /users
Content-Type: application/json
Body: not-json
```

**Response:**
```json
{
  "error": "Invalid request body"
}
```

**Status:** 400

---

### Scenario 3: Resource Not Found (404)

**Trigger:** ID doesn't exist in database

**Request:**
```bash
GET /users/999999
```

**Response:**
```json
{
  "error": "User not found"
}
```

**Status:** 404

---

### Scenario 4: Duplicate Resource (409)

**Trigger:** Username already exists

**Request:**
```bash
POST /users
{"username": "existing", "email": "new@example.com"}
```

**Response:**
```json
{
  "error": "Username already exists"
}
```

**Status:** 409

---

### Scenario 5: Inactive URL (410)

**Trigger:** Short URL exists but is deactivated

**Request:**
```bash
GET /abc123
```

**Response:**
```json
{
  "error": "Short URL is inactive"
}
```

**Status:** 410 (Gone)

---

## 📊 Monitoring & Detection

### Health Endpoint

```bash
GET /health
```

**Normal Response:**
```json
{
  "status": "ok"
}
```
**Status:** 200

**Use Case:** Load balancers check this to route traffic

---

### Container Status Check

```bash
docker compose ps
```

**Healthy Output:**
```
NAME                    STATUS
url-shortener-app       Up 2 hours
url-shortener-db        Up 2 hours
url-shortener-web       Up 2 hours
```

**Unhealthy Output:**
```
NAME                    STATUS
url-shortener-app       Exit 1 (5 seconds ago)
```

---

## 🚨 Recovery Procedures

### Procedure 1: App Container Crash

**Detection:** Health check fails, container status = Exit

**Automatic Recovery:**
1. Docker detects exit code
2. Waits 5 seconds (restart delay)
3. Starts new container
4. Health check passes

**Time to Recovery:** ~5-10 seconds

**Manual Check:**
```bash
docker compose ps
```

---

### Procedure 2: Database Connection Lost

**Detection:** App returns 500 errors

**Automatic Recovery:**
- App retries connection with backoff
- Reconnects when DB is available

**Manual Recovery (if needed):**
```bash
docker compose restart app
```

---

### Procedure 3: Full System Restart

**When to Use:**
- Multiple services failing
- Memory leak suspected
- Configuration changes

**Steps:**
```bash
# Graceful shutdown
docker compose down

# Start fresh
docker compose up -d

# Verify
curl http://localhost:80/health
```

---

## ✅ Success Criteria Checklist

### Chaos Engineering (Gold Tier)

- [x] **Container Auto-Restart**: Kill container → Watch it resurrect
  - Configuration: `restart: unless-stopped`
  - Demo: `scripts/demo-chaos-mode.sh`
  
- [x] **Graceful Failure**: Send garbage data → Get polite error
  - No stack traces exposed
  - Consistent JSON error format
  - Demo: `scripts/demo-graceful-failure.sh`

- [x] **Failure Documentation**: This document
  - Failure mode matrix
  - Recovery procedures
  - Error response examples

---

## 🧪 Running Chaos Tests

### Quick Test (All Demos)
```bash
./scripts/demo-chaos-mode.sh
./scripts/demo-graceful-failure.sh
```

### Manual Container Kill
```bash
# Kill
docker compose kill app

# Watch restart
docker compose ps

# Verify
curl http://localhost:80/health
```

---

## 📈 Metrics to Monitor

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Container Restarts | 0 | 1-2/hour | >5/hour |
| 500 Error Rate | <0.1% | 0.1-1% | >1% |
| Health Check Failures | 0 | 1-2 | >3 |
| Response Time (p95) | <200ms | 200-500ms | >500ms |
