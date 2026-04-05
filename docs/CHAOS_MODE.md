# Chaos Mode - Docker Restart Policy

## Overview

Chaos Mode demonstrates the application's resilience through Docker's restart policy. When the app container crashes or is killed, Docker automatically restarts it without manual intervention.

## Restart Policy Configuration

### Policy Selection

Per [Docker Documentation](https://docs.docker.com/engine/containers/start-containers-automatically/):

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `no` | Don't restart automatically | Default, not suitable for production |
| `on-failure` | Restart only on error (non-zero exit) | Good for crash recovery |
| `always` | Always restart when stopped | **Best for production high-availability** |
| `unless-stopped` | Always restart unless manually stopped | Good for development |

### Our Choice: `restart: always`

**Why `always`?**
- Ensures service availability even if container is manually stopped
- Required for Chaos Mode demonstration (kill → auto-restart)
- Production-grade high availability

**Configuration in `docker-compose.yml`:**
```yaml
services:
  app:
    build: .
    restart: always  # <-- Chaos Mode: Auto-restart on crash
    # ... other config
```

### Full Configuration Context

```yaml
# docker-compose.yml
services:
  app:
    build: .
    environment:
      - DATABASE_HOST=postgres
      - DATABASE_NAME=hackathon_db
      - FLASK_ENV=production
    depends_on:
      - postgres
      - redis
    # Health check for load balancer
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    # Chaos Mode: Auto-restart configuration
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

## Verification Methods

### Method 1: Inspect Running Container

```bash
# Check restart policy of running container
docker inspect pe-hackathon-template-2026-app-1 | grep -A 3 '"RestartPolicy"'
```

**Expected Output:**
```json
"RestartPolicy": {
    "Name": "always",
    "MaximumRetryCount": 0
}
```

### Method 2: Chaos Mode Test Script

```bash
# Run the chaos test
./scripts/demo-chaos-mode.sh
```

**What it does:**
1. Verifies container is running and healthy
2. Kills the container (`docker compose kill app`)
3. Waits for auto-restart (5-10 seconds)
4. Verifies container is running again
5. Confirms health endpoint responds

### Method 3: Manual Verification

```bash
# Step 1: Check initial state
docker compose ps
# Output: app container Up

# Step 2: Verify health
curl http://localhost:5000/health
# Output: {"status":"healthy", ...}

# Step 3: Kill container (simulate crash)
docker compose kill app

# Step 4: Wait 5-10 seconds
sleep 10

# Step 5: Verify auto-restart
docker compose ps
# Output: app container Up (restarted)

# Step 6: Verify service recovery
curl http://localhost:5000/health
# Output: {"status":"healthy", ...}
```

## Expected Behavior

### Before Chaos (Running)
```
NAME      STATUS
app       Up 5 minutes (healthy)
```

### During Chaos (Killed)
```
NAME      STATUS
app       Exited (137)  # Killed
```

### After Chaos (Auto-Restarted)
```
NAME      STATUS
app       Up 3 seconds (health: starting)  # Auto-restarted!
```

## Production Impact

| Metric | Value |
|--------|-------|
| Downtime | ~5-10 seconds |
| Manual Intervention | None required |
| Recovery | Automatic via Docker |
| Data Loss | None (stateless app) |

## Related Configuration

Other services also use restart policy for resilience:

```yaml
# Database - must stay up
postgres:
  restart: always

# Cache - must stay up  
redis:
  restart: always

# Load balancer - entry point
nginx:
  restart: always

# Monitoring
prometheus:
  restart: always
grafana:
  restart: always
```

## References

- [Docker Restart Policy Documentation](https://docs.docker.com/engine/containers/start-containers-automatically/)
- Docker Compose file: `docker-compose.yml`
- Test script: `scripts/demo-chaos-mode.sh`
