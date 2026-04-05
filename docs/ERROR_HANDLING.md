# Error Handling Documentation

## Overview

This document describes how the URL Shortener API handles errors and edge cases.

## HTTP Status Codes

### Success Responses

| Code | Description | Example |
|------|-------------|---------|
| 200 | OK | Successful GET/PUT/DELETE |
| 201 | Created | Successful POST (new resource) |
| 302 | Found | Short URL redirect |

### Client Errors

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 400 | Bad Request | Invalid input data, missing required fields |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate username/email |
| 410 | Gone | URL has been deactivated |
| 415 | Unsupported Media Type | Invalid Content-Type header |

### Server Errors

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 500 | Internal Server Error | Unexpected server error |

## Error Response Format

All errors return JSON with an `error` field:

```json
{
  "error": "Human-readable error message"
}
```

## Common Error Scenarios

### 1. Invalid Input (400)

**Missing required fields:**
```bash
POST /users
Body: {"email": "test@example.com"}  # Missing username

Response:
{
  "error": "Missing required fields: username, email"
}
```

**Invalid email format:**
```bash
POST /users
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

## Validation Rules

| Field | Rules |
|-------|-------|
| username | 3-50 chars, alphanumeric + underscore |
| email | Valid email format required |
| original_url | Valid URL format required |

## Logging

View logs:
```bash
docker compose logs app
```
