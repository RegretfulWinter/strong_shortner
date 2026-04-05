# Failure Modes & Chaos Engineering Documentation

## Overview

This document describes failure scenarios and how the system handles them.

## Failure Mode Matrix

| Component | Failure Mode | Impact | Detection | Recovery |
|-----------|--------------|--------|-----------|----------|
| App Container | Crash/Exit | API unavailable | Health check fails | Docker auto-restart |
| Database | Connection lost | All writes fail | Connection timeout | Retry + fail fast |
| Nginx | Crash | External access lost | Health check | Docker auto-restart |
| Redis | Unavailable | Cache miss only | Connection error | Fallback to DB |

## Container Auto-Restart

### Configuration

`docker-compose.prod.yml` includes:
```yaml
restart: unless-stopped
```

This ensures containers automatically restart on failure.

### Testing Auto-Restart

1. **Kill the app container:**
   ```bash
   docker compose kill app
   ```

2. **Verify it restarts:**
   ```bash
   docker compose ps
   # Should show app container as "Up"
   ```

3. **Check health endpoint:**
   ```bash
   curl http://localhost:80/health
   # Should return {"status": "ok"}
   ```

## Chaos Testing Scripts

### Script 1: Kill Container Test

```bash
#!/bin/bash
# chaos-kill.sh

echo "=== Chaos Test: Kill App Container ==="
docker compose -f docker-compose.prod.yml kill app
echo "Container killed at $(date)"

sleep 5

echo "=== Checking Container Status ==="
docker compose -f docker-compose.prod.yml ps

echo "=== Testing Health Endpoint ==="
curl -f http://localhost:80/health && echo "✅ Auto-restart successful!" || echo "❌ Auto-restart failed!"
```

### Script 2: Database Failure Test

```bash
#!/bin/bash
# chaos-db.sh

echo "=== Chaos Test: Database Connection Loss ==="
docker compose -f docker-compose.prod.yml stop postgres

echo "=== API Response During DB Down ==="
curl http://localhost:80/users
echo ""

echo "=== Restarting Database ==="
docker compose -f docker-compose.prod.yml start postgres
sleep 5

echo "=== API Response After Recovery ==="
curl http://localhost:80/health
echo ""
```

### Script 3: Garbage Input Test

```bash
#!/bin/bash
# chaos-input.sh

echo "=== Chaos Test: Garbage Input ==="

# Test 1: Invalid JSON
echo "Test 1: Invalid JSON"
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d "not valid json"
echo ""

# Test 2: Missing required fields
echo "Test 2: Missing fields"
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
echo ""

# Test 3: Invalid email
echo "Test 3: Invalid email"
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "not-an-email"}'
echo ""

echo "✅ All garbage inputs handled gracefully!"
```

## Graceful Error Responses

### Scenario 1: Database Unavailable

**Request:**
```bash
GET /users
```

**Response:**
```json
{
  "error": "Database connection failed"
}
```
**Status:** 500

### Scenario 2: Invalid Request Body

**Request:**
```bash
POST /users
Body: not-json
```

**Response:**
```json
{
  "error": "Invalid request body"
}
```
**Status:** 400

### Scenario 3: Resource Not Found

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

## Monitoring & Alerts

### Health Endpoint

```bash
GET /health
```

Returns:
```json
{
  "status": "ok"
}
```

### Container Status Check

```bash
docker compose ps
```

Expected output:
```
NAME                STATUS
url-shortener-app   Up 2 hours
url-shortener-db    Up 2 hours
url-shortener-web   Up 2 hours
```

## Recovery Procedures

### 1. App Container Crash

**Automatic:** Docker restarts container within 10 seconds

### 2. Database Connection Lost

**Automatic:** App retries connection
**Manual:** Restart app container if needed

### 3. Full System Restart

```bash
docker compose down
docker compose up -d
```

## Success Criteria

✅ Container restarts automatically after kill
✅ API returns proper error codes (not crashes)
✅ Database reconnection works
✅ Health endpoint always available
