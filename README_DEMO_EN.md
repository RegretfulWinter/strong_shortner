# URL Shortener - Quest Submission Demo

**Branch:** `reliability`  
**Quest:** Reliability Engineering (Bronze/Silver/Gold)

---

## Quick Demo (One Command)

```bash
# Clone and setup
git clone https://github.com/RegretfulWinter/strong_shortner.git
cd strong_shortner
git checkout reliability

# Run the demo
./scripts/chaos-live-demo.sh
```

---

## What This Demonstrates

### 🎯 Chaos Mode (Gold Requirement)

**Requirement:** "Kill the app process or container while it's running. Show it restarts automatically."

**Demo:**
```bash
# Show app running
docker compose ps | grep app
# Output: Up (healthy)

# Kill the app process
docker kill --signal=SIGKILL $(docker compose ps -q app)
# Output: Container killed

# Wait 5-10 seconds...

# Show auto-restarted
docker compose ps | grep app
# Output: Up (restarted!)

# Verify service
curl http://localhost:5001/health
# Output: {"status": "healthy"}
```

**Result:** ✅ Process killed → Container auto-restarted → Service recovered

**Configuration:**
```yaml
# docker-compose.yml
services:
  app:
    restart: always  # Enables auto-recovery
```

---

### 🛡️ Graceful Failure (Gold Requirement)

**Requirement:** "Send garbage data → Get a polite error."

**Demo:**

| Bad Input | Response | HTTP |
|-----------|----------|------|
| `curl -d "not json"` | `{"error": "Invalid JSON"}` | 400 |
| `curl -d '{"email": "bad"}'` | `{"error": "Invalid email format"}` | 400 |
| `curl /users/99999` | `{"error": "User not found"}` | 404 |
| `curl /divide` | `{"error": "Internal server error..."}` | 500 |

**Key Points:**
- ✅ Always returns JSON (never HTML)
- ✅ No stack traces exposed to users
- ✅ Appropriate HTTP status codes
- ✅ Errors logged server-side for debugging

---

## Quest Checklist

| Requirement | Evidence | Status |
|-------------|----------|--------|
| **Unit Tests** | `tests/test_unit.py` - Model CRUD | ✅ |
| **Integration Tests** | `tests/test_integration.py` - API flows | ✅ |
| **Code Coverage >70%** | 79% coverage in CI | ✅ |
| **Health Endpoint** | `/health` - Multi-dimensional JSON | ✅ |
| **Error Handling Docs** | `docs/ERROR_HANDLING.md` | ✅ |
| **Graceful Failure** | Clean JSON errors, no crashes | ✅ |
| **Chaos Mode** | `restart: always`, auto-restart demo | ✅ |

---

## File Structure

```
.
├── docker-compose.yml           # Main config with restart: always
├── docker-compose.chaos.yml     # Simplified for Chaos Mode demo
├── app/
│   ├── __init__.py             # Error handlers (400, 404, 500)
│   └── routes/
│       ├── users.py            # Input validation
│       └── urls.py             # Short URL logic
├── tests/
│   ├── test_unit.py            # Unit tests
│   ├── test_integration.py     # API tests
│   └── test_health.py          # Health endpoint tests
├── scripts/
│   ├── chaos-live-demo.sh      # 🔥 One-command demo
│   └── test_graceful_failure.sh # Error handling tests
└── docs/
    ├── ERROR_HANDLING.md       # Error handling documentation
    ├── CHAOS_MODE.md           # Chaos Mode documentation
    └── EVIDENCE.md             # Test evidence
```

---

## Live Demo Commands

### Option 1: Automated Demo (Recommended)

```bash
./scripts/chaos-live-demo.sh
```

### Option 2: Manual Step-by-Step

```bash
# 1. Start services
docker compose -f docker-compose.chaos.yml up -d

# 2. Chaos Mode - Kill & Restart
## Show running
docker compose ps | grep app
curl http://localhost:5001/health

## Kill process
CONTAINER=$(docker compose ps -q app)
docker kill --signal=SIGKILL $CONTAINER

## Wait & verify restart
sleep 10
docker compose ps | grep app
curl http://localhost:5001/health

# 3. Graceful Failure Tests
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d '{"email": "invalid"}'

curl http://localhost:5001/users/99999

curl http://localhost:5001/divide
```

---

## CI/CD Evidence

GitHub Actions runs all tests on every push:

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    steps:
      - name: Run Unit Tests
        run: pytest tests/test_unit.py -v
      
      - name: Run Integration Tests
        run: pytest tests/test_integration.py -v
      
      - name: Generate Coverage Report
        run: pytest --cov=app --cov-report=term
```

**Latest run:** https://github.com/RegretfulWinter/strong_shortner/actions

---

## Production Deployment

**Server:** Vultr VPS (45.63.124.31)  
**Deployment:** GitHub Actions → SSH → Docker Compose

```bash
# Production environment uses same config
# Docker restart policy ensures high availability
```

---

## Notes

- **macOS Docker Desktop:** Has limitations with `restart: always`. Demo uses a watcher script.
- **Linux Production:** `restart: always` works natively without scripts.
- **Downtime:** ~5-10 seconds for auto-restart.
- **Data Loss:** None (stateless app design).

---

## Contact

For questions about this submission, refer to:
- Demo script: `./scripts/chaos-live-demo.sh`
- Documentation: `./docs/`
- Tests: `./tests/`
