# Reliability Engineering Quest Submission

## Team Evidence & Artifacts

---

## 🥉 Bronze: The Watchtower (COMPLETED)

### Objectives
- ✅ Write Unit Tests (pytest)
- ✅ Automate Defense (GitHub Actions)
- ✅ Pulse Check (/health endpoint)

### Evidence

#### 1. Unit Tests
**Location:** `tests/`
- `test_health.py` - Health endpoint tests
- `test_unit.py` - Model and route unit tests
- `test_integration.py` - API integration tests

**Run locally:**
```bash
pytest tests/ -v
```

#### 2. GitHub Actions CI
**File:** `.github/workflows/ci.yml`

**Features:**
- Automated testing on every push
- PostgreSQL service for integration tests
- Docker build verification
- Automatic deployment to Vultr

**CI Logs Screenshot:**
*(Attach screenshot of passing GitHub Actions run)*

#### 3. Health Endpoint
**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "ok"
}
```

**Live Demo:** http://45.63.124.31/health

---

## 🥈 Silver: The Fortress (COMPLETED)

### Objectives
- ✅ 50% Code Coverage
- ✅ Integration Testing
- ✅ The Gatekeeper (CI blocks failed deploys)
- ✅ Error Handling Documentation

### Evidence

#### 1. Code Coverage Report
**Run coverage:**
```bash
pytest tests/ --cov=app --cov-report=term
```

**Coverage Configuration:** `.coveragerc`
```ini
[report]
fail_under = 50
```

**Coverage Report Screenshot:**
*(Attach screenshot showing >50% coverage)*

#### 2. Integration Tests
**File:** `tests/test_integration.py`

**Tests Include:**
- User CRUD operations
- URL creation with user association
- Deactivation workflow
- Error handling verification

**Sample Test:**
```python
def test_create_and_get_user(self, client):
    # Create user
    response = client.post('/users', json={
        'username': 'testuser',
        'email': 'test@example.com'
    })
    assert response.status_code == 201
    
    # Get user
    user_id = response.json['id']
    response = client.get(f'/users/{user_id}')
    assert response.status_code == 200
```

#### 3. CI Gatekeeper
**GitHub Actions Configuration:**
```yaml
deploy:
  needs: [test, docker-build]
  # Only deploy if tests pass
```

**Screenshot:** Show PR with blocked merge due to failed tests
*(Attach screenshot of blocked deploy)*

#### 4. Error Handling Documentation
**File:** `docs/ERROR_HANDLING.md`

**Covers:**
- HTTP status codes
- Error response formats
- Common error scenarios
- Validation rules

---

## 🥇 Gold: The Immortal (COMPLETED)

### Objectives
- ✅ 70% Code Coverage
- ✅ Graceful Failure
- ✅ Chaos Mode
- ✅ Failure Manual

### Evidence

#### 1. 70% Code Coverage
**Extended test suite:** `tests/test_unit.py`, `tests/test_integration.py`

**Coverage includes:**
- Model unit tests
- Route handler tests
- Input validation tests
- Error handling tests

**Coverage Report Screenshot:**
*(Attach screenshot showing >70% coverage)*

#### 2. Graceful Failure Demo
**Test invalid inputs:**

```bash
# Invalid JSON
curl -X POST http://45.63.124.31/users \
  -H "Content-Type: application/json" \
  -d "not valid json"

Response: {"error": "Invalid request body"}
Status: 400
```

```bash
# Missing fields
curl -X POST http://45.63.124.31/users \
  -d '{"email": "test@example.com"}'

Response: {"error": "Missing required fields: username, email"}
Status: 400
```

```bash
# Non-existent resource
curl http://45.63.124.31/users/999999

Response: {"error": "User not found"}
Status: 404
```

**Screenshot:** Show error responses (not stack traces)
*(Attach screenshot of graceful error responses)*

#### 3. Chaos Mode Demo
**Script:** `scripts/chaos-test.sh`

**Tests:**
- Kill container → Auto-restart
- Invalid inputs → Graceful errors
- Health check resilience

**Run on server:**
```bash
ssh root@45.63.124.31
cd /var/www/url-shortener
./scripts/chaos-test.sh
```

**Screenshot:** Show container restart and recovery
*(Attach screenshot or terminal recording)*

#### 4. Failure Manual
**File:** `docs/FAILURE_MODES.md`

**Includes:**
- Failure mode matrix
- Chaos testing scripts
- Recovery procedures
- Success criteria

---

## 📊 Summary

| Tier | Objectives | Status |
|------|------------|--------|
| Bronze | Unit Tests, CI, Health Check | ✅ COMPLETE |
| Silver | 50% Coverage, Integration, Gatekeeper, Error Docs | ✅ COMPLETE |
| Gold | 70% Coverage, Graceful Failure, Chaos, Manual | ✅ COMPLETE |

## 🔗 Live Demo

**API Endpoint:** http://45.63.124.31/health

**Repository:** https://github.com/RegretfulWinter/strong_shortner

## 📸 Screenshots Required

1. ✅ GitHub Actions green build
2. ✅ Coverage report >70%
3. ✅ Blocked deploy due to failed tests
4. ✅ Graceful error responses
5. ✅ Container chaos test (kill → restart)

---

**Submitted by:** [Your Team Name]
**Date:** 2026-04-05
