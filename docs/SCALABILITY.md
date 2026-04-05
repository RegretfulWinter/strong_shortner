# Scalability Quest Documentation

## Bronze Tier: The Crowd

### Objective
Simulate 50 concurrent users hitting the service and record baseline metrics.

### Requirements
- ✅ 50 concurrent users (simultaneous clicks)
- ✅ Record response time (latency)
- ✅ Record error rate
- ✅ Screenshot of terminal output
- ✅ Documented baseline p95 response time

### Test Tools

#### Option 1: Strict 50 Concurrent Users (Recommended)
```bash
# 50 users hit API at the EXACT same moment
./scripts/scalability-concurrent-50.sh

# Result: P95=0.3ms, Error Rate=0%
```

#### Option 2: k6 Load Test
```bash
# Install k6
brew install k6  # macOS

# Run test
k6 run load_test.js
```

#### Option 3: Simple Bash Script
```bash
./scripts/scalability-bronze.sh
```

### Baseline Results

**Test Configuration:**
- Concurrent Users: 50
- Total Requests: 500
- Test Duration: ~50 seconds
- Endpoints Tested:
  - GET /health
  - GET /users
  - GET /urls

**Expected Metrics:**
- P95 Response Time: < 500ms (baseline)
- Error Rate: < 10%

### Sample Output - Strict Concurrent Test

```bash
$ ./scripts/scalability-concurrent-50.sh

==========================================
  STRICT CONCURRENT TEST - 50 USERS
  All hitting API at exact same second
==========================================

🔥 FIRE! All 50 users clicking now!

All requests completed in 1 seconds

Response Time Distribution:
---------------------------
Min: 0.161942ms
Max: 0.342887ms
Avg: 0.25ms
P50 (Median): 0.252843ms
P95: 0.305803ms
P99: 0.335193ms

Summary:
--------
Concurrent Users: 50
Total Requests:       50
Successful (HTTP 200): 50
Errors: 0
Error Rate: 0%

==========================================
  STRICT CONCURRENT TEST RESULTS
==========================================

✅ P95 Response Time: 0.305803ms (under 500ms)
   BASELINE P95: 0.305803ms
✅ Error Rate: 0% (under 10%)

==========================================
```

### Screenshot Requirements

Please capture:
1. Terminal showing "50 Concurrent Users"
2. P95 response time value
3. Error rate percentage

### Files

- `load_test.js` - k6 load test script
- `scripts/scalability-bronze.sh` - Bash load test script
- `docs/SCALABILITY.md` - This documentation

### Next Steps (Silver/Gold)

- **Silver**: Add Redis caching, implement horizontal scaling
- **Gold**: Auto-scaling based on CPU/memory metrics
