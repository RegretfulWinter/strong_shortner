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

#### Option 1: k6 (Recommended)
```bash
# Install k6
brew install k6  # macOS
# or download from https://k6.io/

# Run test
k6 run load_test.js

# With custom API URL
API_URL=http://localhost:5001 k6 run load_test.js
```

#### Option 2: Bash Script
```bash
# Run the bash-based load test
./scripts/scalability-bronze.sh

# With custom API URL
API_URL=http://localhost:5001 ./scripts/scalability-bronze.sh
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

### Sample Output

```
==========================================
  SCALABILITY BRONZE TEST
  50 Concurrent Users Simulation
==========================================

Response Time Distribution:
---------------------------
P50 (Median): 45ms
P95: 120ms
P99: 180ms

Summary:
--------
Total Requests: 500
Successful: 500
Errors: 0
Error Rate: 0%

==========================================
  BASELINE P95 RESPONSE TIME: 120ms
==========================================

✅ PASS: P95 is under 500ms
✅ PASS: Error rate is under 10%
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
