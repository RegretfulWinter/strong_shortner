# Live Demo Script (English)

For judges: Watch me kill the app process and see it auto-restart.

---

## Quick Start

```bash
./scripts/chaos-live-demo.sh
```

---

## Part 1: Chaos Mode - Kill Process & Auto-Restart

**Tell judges:** "Now I'll simulate a production crash by killing the app process. Watch how Docker automatically restarts the container."

### Step 1: Show container is running

```bash
docker compose -f docker-compose.chaos.yml ps | grep app
```

**Expected:**
```
pe-hackathon-template-2026-app-1 ... Up 2 minutes (healthy)
```

**Say:** "The app container is running and healthy."

---

### Step 2: Verify health endpoint works

```bash
curl http://localhost:5001/health
```

**Expected:** `{"status": "healthy", ...}`

**Say:** "Health check passes. Now I'll kill the app process."

---

### Step 3: Show running processes

```bash
docker compose -f docker-compose.chaos.yml top app
```

**Say:** "This shows gunicorn (the WSGI server) running as the main process."

---

### Step 4: KILL the app process (The Chaos)

```bash
# Get container ID
CONTAINER=$(docker compose -f docker-compose.chaos.yml ps -q app)

# Kill the main process (PID 1)
docker kill --signal=SIGKILL $CONTAINER
```

**Say:** "I just sent SIGKILL to the container's main process. This simulates a crash."

---

### Step 5: Show container stopped

```bash
docker compose -f docker-compose.chaos.yml ps | grep app
```

**Expected:** No output (container not running)

**Say:** "The container has stopped because the main process died. But Docker's restart policy is set to 'always'."

---

### Step 6: Watch auto-restart

```bash
# Wait and check
sleep 10
docker compose -f docker-compose.chaos.yml ps | grep app
```

**Expected:**
```
pe-hackathon-template-2026-app-1 ... Up 3 seconds
```

**Say:** "It's back! Docker automatically created a new container."

---

### Step 7: Verify service recovery

```bash
curl http://localhost:5001/health | grep status
```

**Expected:** `"healthy"`

**Say:** "Health check passes. The service has fully recovered with zero manual intervention."

---

## Part 2: Graceful Failure - Garbage In, Polite Error Out

**Tell judges:** "Now I'll demonstrate how the app handles bad inputs gracefully. No crashes, no stack traces, just clean JSON errors."

### Test 1: Invalid JSON (Garbage data)

```bash
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d "this is not json"
```

**Expected:**
```json
{"error": "Invalid JSON"}
```

**Say:** "Garbage JSON in, polite error out. The app doesn't crash."

---

### Test 2: Invalid email format

```bash
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "not-an-email"}'
```

**Expected:**
```json
{"error": "Invalid email format"}
```

**Say:** "Input validation. Clean error message, no stack trace."

---

### Test 3: Missing required fields

```bash
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test"}'
```

**Expected:**
```json
{"error": "Missing required fields: email"}
```

**Say:** "Missing data? Clear error response, not an exception."

---

### Test 4: Resource not found (404)

```bash
curl http://localhost:5001/users/99999
```

**Expected:**
```json
{"error": "User not found"}
```

**Say:** "404 with JSON, not HTML. API-friendly error handling."

---

### Test 5: Runtime error (500) - The real test

```bash
curl http://localhost:5001/divide
```

**Expected:**
```json
{"error": "Internal server error. Please try again later."}
```

**Say:** "This simulates a real bug - divide by zero.  
The stack trace is logged server-side for debugging,  
but the user only sees this clean message. No internal details leaked."

---

## Summary for Judges

| What I Demonstrated | What Happened | Why It Matters |
|---------------------|---------------|----------------|
| **Chaos Mode** | Killed app process → Auto-restart in ~5s | High availability |
| **Graceful 400** | Invalid JSON → Clean error | No crashes |
| **Graceful 404** | Resource not found → JSON error | Good API design |
| **Graceful 500** | Runtime bug → No stack trace | Security |

---

## Configuration Reference

**Docker Restart Policy (docker-compose.yml):**
```yaml
services:
  app:
    restart: always  # Enables auto-restart on crash
```

**Options:**
- `no` - Don't restart (default)
- `on-failure` - Restart only on error
- `always` - **Always restart (our choice for Chaos Mode)**
- `unless-stopped` - Restart unless manually stopped

---

## Quick Commands (Copy-Paste)

```bash
# === CHAOS MODE ===
docker compose -f docker-compose.chaos.yml ps | grep app
curl http://localhost:5001/health
CONTAINER=$(docker compose -f docker-compose.chaos.yml ps -q app)
docker kill --signal=SIGKILL $CONTAINER
sleep 10
docker compose -f docker-compose.chaos.yml ps | grep app
curl http://localhost:5001/health

# === GRACEFUL FAILURE ===
curl -X POST http://localhost:5001/users -H "Content-Type: application/json" -d "not json"
curl http://localhost:5001/users/99999
curl http://localhost:5001/divide
```

---

## Notes for macOS Users

Docker Desktop on macOS has limitations with `restart: always`. The demo uses a watcher script to ensure auto-restart behavior.

**On Linux production servers (like Vultr), `restart: always` works natively without any additional scripts.**

---

## One-Command Demo

```bash
./scripts/chaos-live-demo.sh
```

This runs the complete Chaos Mode demonstration automatically.
