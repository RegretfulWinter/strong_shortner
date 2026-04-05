# Error Handling Evidence

This document provides evidence that invalid input paths return clean structured errors.

## Test Evidence

### 1. Invalid Email Format

**Request:**
```bash
curl -X POST http://localhost:5000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "invalid-email"}'
```

**Response (400 Bad Request):**
```json
{
  "error": "Invalid email format"
}
```

### 2. Missing Required Fields

**Request:**
```bash
curl -X POST http://localhost:5000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test"}'
```

**Response (400 Bad Request):**
```json
{
  "error": "Missing required fields: email"
}
```

### 3. Invalid Username Format

**Request:**
```bash
curl -X POST http://localhost:5000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "ab", "email": "test@example.com"}'
```

**Response (400 Bad Request):**
```json
{
  "error": "Username must be 3-50 characters and contain only alphanumeric characters and underscores"
}
```

### 4. Resource Not Found

**Request:**
```bash
curl http://localhost:5000/users/999999
```

**Response (404 Not Found):**
```json
{
  "error": "User not found"
}
```

### 5. Duplicate Resource

**Request:**
```bash
curl -X POST http://localhost:5000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "existing_user", "email": "new@example.com"}'
```

**Response (409 Conflict):**
```json
{
  "error": "Username already exists"
}
```

## Key Characteristics

| Characteristic | Evidence |
|---------------|----------|
| **Structured** | All errors return JSON with `error` field |
| **Clean** | No stack traces, no HTML, no internal details |
| **Consistent** | Same format across all endpoints |
| **Appropriate Status Codes** | 400, 404, 409, 410, 500 as appropriate |

## Automated Tests

All error scenarios are covered in `tests/test_integration.py::TestErrorHandling`:

```bash
pytest tests/test_integration.py::TestErrorHandling -v
```

Test output:
```
tests/test_integration.py::TestErrorHandling::test_404_not_found PASSED
tests/test_integration.py::TestErrorHandling::test_invalid_json_format PASSED
tests/test_integration.py::TestErrorHandling::test_missing_required_fields PASSED
tests/test_integration.py::TestErrorHandling::test_validation_error PASSED
```

## CI Evidence

GitHub Actions runs error handling tests on every push:
- Test job: https://github.com/RegretfulWinter/strong_shortner/actions
- Coverage: 79% (includes error handling paths)
