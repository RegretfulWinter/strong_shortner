# Live Demo Script

> For judges: Watch me kill the container and see it auto-restart.  
> Watch me send garbage data and see polite errors.

---

## Part 1: Chaos Mode - Kill & Resurrect

**Tell judges:** "Now I'll simulate a production crash by killing the app container. Watch Docker automatically restart it."

### Step 1: Show container is running

```bash
docker compose ps | grep app
```

**Expected output:**
```
pe-hackathon-template-2026-app-1 ... Up 2 minutes (healthy)
```

**Say:** "App is running and healthy."

---

### Step 2: Verify health endpoint works

```bash
curl http://localhost:80/health | jq
```

**Expected:** `{"status": "healthy", ...}`

**Say:** "Health check passes. Now I'll kill the container."

---

### Step 3: KILL the container (The Chaos)

```bash
docker compose kill app
```

**Expected:** `Container pe-hackathon-template-2026-app-1  Killed`

**Say:** "Container killed! Simulating a crash."

---

### Step 4: Show it's dead

```bash
docker compose ps | grep app
```

**Expected:** No output (container not running)

**Say:** "Container is gone. But wait... Docker restart policy is set to 'always'."

---

### Step 5: Wait and watch resurrection

```bash
echo "Waiting 10 seconds for auto-restart..."
sleep 10
docker compose ps | grep app
```

**Expected:**
```
pe-hackathon-template-2026-app-1 ... Up 3 seconds (health: starting)
```

**Say:** "It's back! Docker automatically restarted it."

---

### Step 6: Verify it's working again

```bash
curl http://localhost:80/health | jq .status
```

**Expected:** `"healthy"`

**Say:** "Health check passes. Zero manual intervention. This is Chaos Mode."

---

## Part 2: Graceful Failure - Garbage In, Polite Error Out

**Tell judges:** "Now I'll show how the app handles bad inputs. No crashes, no stack traces, just clean JSON errors."

---

### Test 1: Invalid JSON (Garbage data)

```bash
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d "this is not json"
```

**Expected:**
```json
{"error": "Invalid JSON"}
```

**Say:** "Garbage JSON in, polite error out. App doesn't crash."

---

### Test 2: Invalid email format

```bash
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "not-an-email"}'
```

**Expected:**
```json
{"error": "Invalid email format"}
```

**Say:** "Input validation. Clean error message."

---

### Test 3: Missing required fields

```bash
curl -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test"}'
```

**Expected:**
```json
{"error": "Missing required fields: email"}
```

**Say:** "Missing data? Clear error, not a stack trace."

---

### Test 4: Resource not found (404)

```bash
curl http://localhost:80/users/99999
```

**Expected:**
```json
{"error": "User not found"}
```

**Say:** "404 with JSON, not HTML. API-friendly."

---

### Test 5: Runtime error (500) - The real test

```bash
curl http://localhost:80/divide
```

**Expected:**
```json
{"error": "Internal server error. Please try again later."}
```

**Say:** "This simulates a real bug - divide by zero.  
Stack trace is logged server-side, but user sees only this clean message.  
No internal details leaked."

---

## Summary for Judges

| What I Did | What Happened | Why It Matters |
|------------|---------------|----------------|
| Killed container | Auto-restarted in 10s | High availability |
| Sent garbage JSON | Clean 400 error | No crashes |
| Invalid email | Validation error | Input safety |
| Requested non-existent user | Clean 404 | Good API design |
| Triggered runtime bug | Clean 500, no stack trace | Security |

---

## Quick Commands (Copy-Paste Version)

```bash
# === CHAOS MODE ===
docker compose ps | grep app
curl http://localhost:80/health | jq
docker compose kill app
docker compose ps | grep app  # shows nothing
sleep 10
docker compose ps | grep app  # shows restarted
curl http://localhost:80/health | jq

# === GRACEFUL FAILURE ===
curl -X POST http://localhost:80/users -H "Content-Type: application/json" -d "not json"
curl -X POST http://localhost:80/users -H "Content-Type: application/json" -d '{"email": "bad"}'
curl http://localhost:80/users/99999
curl http://localhost:80/divide
```
