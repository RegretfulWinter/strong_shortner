# Graceful Failure Verification

## Quick Check (One Command)

Run this to verify all error handling:

```bash
curl -s https://raw.githubusercontent.com/RegretfulWinter/strong_shortner/reliability/scripts/test_graceful_failure.sh | bash
```

Or locally:
```bash
./scripts/test_graceful_failure.sh
```

## Manual Verification

Send garbage data → Get polite JSON errors:

### 1. Invalid Email
```bash
curl -X POST http://45.63.124.31/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "not-an-email"}'
```
**Result:** `{"error": "Invalid email format"}` ✓

### 2. Missing Fields
```bash
curl -X POST http://45.63.124.31/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test"}'
```
**Result:** `{"error": "Missing required fields: email"}` ✓

### 3. Garbage JSON
```bash
curl -X POST http://45.63.124.31/users \
  -H "Content-Type: application/json" \
  -d 'this is not json'
```
**Result:** `{"error": "Invalid JSON"}` ✓

### 4. SQL Injection Attempt
```bash
curl -X POST http://45.63.124.31/users \
  -H "Content-Type: application/json" \
  -d '{"username": "'\'' OR '\''1'\''='\''1", "email": "test@test.com"}'
```
**Result:** Validation error (app doesn't crash) ✓

### 5. Non-existent Resource (404)
```bash
curl http://45.63.124.31/users/999999
```
**Result:** `{"error": "User not found"}` ✓

### 6. Server Error (500) - Runtime Bug
```bash
curl http://45.63.124.31/divide
```
**Result:** `{"error": "Internal server error. Please try again later."}` ✓

> **What this simulates:** A real bug in code (e.g., divide by zero, null pointer)  
> **What should NOT happen:** Stack trace exposed to user, app crashes  
> **What SHOULD happen:** Clean JSON error, error logged server-side

## What "Graceful" Means

| Bad Input | Bad Response (❌) | Good Response (✅) |
|-----------|------------------|-------------------|
| Invalid email | Stack trace / HTML | `{"error": "Invalid email format"}` |
| Garbage JSON | App crash | `{"error": "Invalid JSON"}` |
| SQL injection | Database error | Validation error |
| Empty body | 500 error | `{"error": "Missing required fields"}` |

## Evidence

- **Script**: `scripts/test_graceful_failure.sh`
- **Tests**: `tests/test_integration.py::TestErrorHandling`
- **CI**: Runs on every push via GitHub Actions
