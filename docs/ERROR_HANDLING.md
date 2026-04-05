# Error Handling Documentation

## Overview

This document describes how the URL Shortener API handles errors and edge cases.

## HTTP Status Codes

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 200 | OK | Successful GET/PUT/DELETE |
| 201 | Created | Successful POST (new resource) |
| 302 | Found | Short URL redirect |
| 400 | Bad Request | Invalid input data, missing required fields |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate username/email |
| 410 | Gone | URL has been deactivated |
| 500 | Internal Server Error | Unexpected server error |

## Error Response Format

All errors return JSON with consistent structure:

```json
{
  "error": "Human-readable error message"
}
```

## Error Scenarios

### 400 Bad Request

**Missing required fields:**
```bash
POST /users
Body: {"email": "test@example.com"}  # Missing username

Response: {"error": "Missing required fields: username, email"}
```

**Invalid email format:**
```bash
POST /users
Body: {"username": "test", "email": "not-an-email"}

Response: {"error": "Invalid email format"}
```

**Invalid username format:**
```bash
POST /users
Body: {"username": "a", "email": "test@example.com"}

Response: {"error": "Username must be 3-50 characters and contain only alphanumeric characters and underscores"}
```

### 404 Not Found

```bash
GET /users/999999

Response: {"error": "User not found"}
```

### 409 Conflict

```bash
POST /users
Body: {"username": "existing", "email": "new@example.com"}

Response: {"error": "Username already exists"}
```

### 410 Gone

```bash
GET /abc123  # Short code exists but is deactivated

Response: {"error": "Short URL is inactive"}
```

### 500 Internal Server Error

```bash
Response: {"error": "Internal server error. Please try again later."}
```

Note: Stack traces are logged server-side, not exposed to users.

## Validation Rules

| Field | Rules |
|-------|-------|
| username | 3-50 chars, alphanumeric + underscore |
| email | Valid email format (RFC 5322) |
| original_url | Valid URL format required |

## Implementation Examples

### 404 Handling

```python
@users_bp.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    try:
        user = User.get_by_id(user_id)
        return jsonify(model_to_dict(user))
    except User.DoesNotExist:
        return jsonify({"error": "User not found"}), 404
```

### 500 Error Handler

```python
@app.errorhandler(500)
def handle_500(error):
    app.logger.error(f"Internal error: {error}", exc_info=True)
    return jsonify({"error": "Internal server error. Please try again later."}), 500
```

### Input Validation

```python
import re

EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
USERNAME_REGEX = re.compile(r'^[a-zA-Z0-9_]{3,50}$')

def validate_user_input(data):
    if not EMAIL_REGEX.match(data.get('email', '')):
        return {"error": "Invalid email format"}, 400
    if not USERNAME_REGEX.match(data.get('username', '')):
        return {"error": "Invalid username format"}, 400
```

## Testing

Run error handling tests:
```bash
pytest tests/test_integration.py::TestErrorHandling -v
```

Tests verify:
- 404 returns JSON (not HTML)
- 400 validates all input fields
- 500 returns generic message (no stack trace)
