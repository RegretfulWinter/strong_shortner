# Local Demo Guide

Complete walkthrough for demonstrating the URL Shortener project locally.

## Prerequisites

```bash
# Ensure Docker Desktop is running
docker info

# Ensure you're in the project directory
cd /Users/jiehuima/Desktop/Meta_PE_Hackathon/PE-Hackathon-Template-2026
```

---

## Demo Flow

### Step 1: Start All Services (Terminal 1)

```bash
# Start everything
docker compose up -d

# Wait for all services to be healthy
sleep 15

# Verify all running
docker compose ps
```

**Expected:** All containers show "Up" status

---

### Step 2: Quick Health Check

```bash
# Via Nginx (port 80)
curl http://localhost:80/health | jq

# Or open in browser
open http://localhost:80/health
```

**Expected:** JSON response with `{"status": "healthy", ...}`

---

### Step 3: Basic API Demo - Create User

```bash
# Create a user
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"username": "demo_user", "email": "demo@example.com"}' | jq
```

**Expected:**
```json
{
  "id": 1,
  "username": "demo_user",
  "email": "demo@example.com"
}
```

---

### Step 4: Graceful Failure Demo (400/404)

```bash
# 400 - Invalid email
echo "=== 400 Error Demo ==="
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "bad-email"}' | jq

# 404 - Not found
echo "=== 404 Error Demo ==="
curl http://localhost:80/users/99999 | jq

# 500 - Runtime error
echo "=== 500 Error Demo ==="
curl http://localhost:80/divide | jq
```

**Expected:** Clean JSON errors, no stack traces

---

### Step 5: URL Shortener Demo

```bash
# Create short URL
echo "=== Create Short URL ==="
URL_RESPONSE=$(curl -s -X POST http://localhost:80/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://www.google.com", "user_id": 1}')
echo "$URL_RESPONSE" | jq

# Extract short code
SHORT_CODE=$(echo "$URL_RESPONSE" | jq -r '.short_code')
echo "Short code: $SHORT_CODE"

# Test redirect (will show 302)
echo "=== Test Redirect ==="
curl -v http://localhost:80/$SHORT_CODE 2>&1 | grep "< HTTP"
```

---

### Step 6: Chaos Mode Demo (Terminal 2)

**Open a second terminal window:**

```bash
cd /Users/jiehuima/Desktop/Meta_PE_Hackathon/PE-Hackathon-Template-2026
./scripts/demo-chaos-mode-macos.sh
```

**What to show:**
1. Container running
2. Kill container (simulate crash)
3. Container auto-restarts
4. Health check passes

---

### Step 7: Monitoring Dashboard (Optional)

```bash
# Open Grafana
open http://localhost:3000

# Login: admin/admin
```

---

## One-Command Full Demo

```bash
./scripts/full-demo.sh
```

This runs all steps automatically with pauses for explanation.

---

## Quick Screenshot Checklist

| Feature | Command | Expected |
|---------|---------|----------|
| Health | `curl localhost:80/health` | JSON with status |
| Create User | `curl -X POST ...` | User JSON |
| 400 Error | Invalid email | `{"error": "..."}` |
| 404 Error | Non-existent user | `{"error": "..."}` |
| 500 Error | `/divide` | `{"error": "..."}` |
| Chaos Mode | `./scripts/demo-chaos-mode-macos.sh` | ✅ PASSED |
| Docker PS | `docker compose ps` | All Up |

---

## Troubleshooting

### Port already in use
```bash
# Find what's using port 80
lsof -i :80

# Or use different port in docker-compose.yml
ports:
  - "8080:80"
```

### Container not starting
```bash
# Check logs
docker compose logs app

# Restart
docker compose restart app
```

### Health check fails
```bash
# Wait longer
docker compose ps
# Look for (healthy) status
```
