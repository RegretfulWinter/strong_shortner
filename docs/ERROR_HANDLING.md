# Error Handling Documentation

## Overview

This document describes how the URL Shortener API handles errors and edge cases following software engineering best practices.

## HTTP Status Codes

### Success Responses

| Code | Description | Example |
|------|-------------|---------|
| 200 | OK | Successful GET/PUT/DELETE |
| 201 | Created | Successful POST (new resource) |
| 302 | Found | Short URL redirect |

### Client Errors (4xx)

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 400 | Bad Request | Invalid input data, missing required fields |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate username/email |
| 410 | Gone | URL has been deactivated |
| 415 | Unsupported Media Type | Invalid Content-Type header |

### Server Errors (5xx)

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 500 | Internal Server Error | Unexpected server error |

---

## 🎯 Error Handling Philosophy

### Principles

1. **Fail Fast**: Validate input at the boundary before processing
2. **Clear Messages**: Provide actionable error messages
3. **No Stack Traces in Production**: Internal errors are logged, users see clean messages
4. **Consistent Format**: All errors return JSON with `error` field
5. **Appropriate Status Codes**: Use correct HTTP status codes for different error types

---

## 404 Not Found - Engineering Practice

### Implementation Pattern

**Principle**: Resources that don't exist should return 404 immediately without side effects.

**Pattern: "Look Before You Leap"**

```python
@users_bp.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    try:
        user = User.get_by_id(user_id)
        return jsonify(model_to_dict(user))
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404
```

**Why This Matters:**
- **Idempotency**: Multiple identical 404 requests have the same effect (no change)
- **Security**: Doesn't leak whether ID ever existed vs currently doesn't exist
- **Caching**: 404s can be cached by intermediate proxies
- **Debugging**: Clear separation between "exists but you can't see it" (403) vs "doesn't exist" (404)

**Common 404 Scenarios:**

| Endpoint | Scenario | Response |
|----------|----------|----------|
| GET /users/999 | User never existed | 404 |
| GET /users/123 | User was deleted | 404 |
| GET /urls/abc123 | Short code doesn't exist | 404 |
| PUT /users/999 | Update non-existent user | 404 |
| DELETE /users/999 | Delete non-existent user | 404 |

---

## 500 Internal Server Error - Engineering Practice

### Implementation Pattern

**Principle**: Unexpected errors are caught, logged, and return generic messages to users.

**Pattern: "Catch-Log-Respond"**

```python
@app.errorhandler(500)
def handle_500(error):
    # Log full traceback for debugging
    app.logger.error(f"Internal error: {error}", exc_info=True)
    
    # Return generic message to user (no stack trace!)
    return jsonify({
        "error": "Internal server error. Please try again later."
    }), 500
```

**Why This Matters:**
- **Security**: Stack traces reveal code structure, file paths, internal logic
- **User Experience**: Users don't need technical details, just actionable info
- **Debugging**: Errors are logged server-side for developers
- **Graceful Degradation**: App doesn't crash, returns controlled response

**What Triggers 500:**
- Database connection failures
- Unhandled exceptions in route handlers
- External service failures
- Configuration errors

**Production vs Development:**

| Environment | User Sees | Developer Sees |
|-------------|-----------|----------------|
| Development | Detailed stack trace | Full traceback in console |
| Production | Generic error message | Full logs in `docker compose logs` |

---

## Error Response Format

All errors return JSON with consistent structure:

```json
{
  "error": "Human-readable error message",
  "code": "OPTIONAL_ERROR_CODE"
}
```

**Examples:**

**Validation Error (400):**
```json
{
  "error": "Missing required fields: username, email"
}
```

**Not Found (404):**
```json
{
  "error": "User not found"
}
```

**Server Error (500):**
```json
{
  "error": "Internal server error. Please try again later."
}
```

---

## Common Error Scenarios

### 1. Invalid Input (400)

**Missing required fields:**
```bash
POST /users
Content-Type: application/json
Body: {"email": "test@example.com"}  # Missing username

Response:
{
  "error": "Missing required fields: username, email"
}
```

**Invalid email format:**
```bash
POST /users
Content-Type: application/json
Body: {"username": "test", "email": "not-an-email"}

Response:
{
  "error": "Invalid email format"
}
```

### 2. Resource Not Found (404)

```bash
GET /users/999999  # User doesn't exist

Response:
{
  "error": "User not found"
}
```

### 3. Duplicate Resources (409)

```bash
POST /users
Content-Type: application/json
Body: {"username": "existing", "email": "new@example.com"}

Response:
{
  "error": "Username already exists"
}
```

### 4. Inactive URL (410)

```bash
GET /abc123  # Short code exists but is deactivated

Response:
{
  "error": "Short URL is inactive"
}
```

---

## Validation Rules

| Field | Rules |
|-------|-------|
| username | 3-50 chars, alphanumeric + underscore |
| email | Valid email format required |
| original_url | Valid URL format required |

---

## Logging

View logs:
```bash
docker compose logs app
```

Production logs include:
- Timestamp
- Error type
- Request path
- User agent
- Stack traces (for 500 errors)

---

## Testing Error Handling

Run tests that verify error responses:
```bash
pytest tests/test_integration.py::TestErrorHandling -v
```

This ensures:
- 404 returns proper JSON (not HTML)
- 400 validates all input fields
- 500 doesn't leak stack traces
