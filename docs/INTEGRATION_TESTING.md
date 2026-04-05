# Integration Testing Documentation

## Overview

Integration tests verify that different components of the application work together correctly. Unlike unit tests that mock dependencies, integration tests use real database operations.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Test Client   │────▶│   Flask App     │────▶│   PostgreSQL    │
│   (pytest)      │     │   (Routes)      │     │   (Real DB)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
    Send HTTP              Process Request           Persist Data
    Requests               Validate Input            Query/Insert
```

## Test Categories

### 1. User API Integration Tests

#### Test: `test_create_and_get_user`
**Purpose**: Verify user creation and retrieval flow

**APIs Hit:**
- `POST /users` - Create user
- `GET /users/{id}` - Retrieve created user

**Database Operations:**
- INSERT INTO users (username, email, created_at)
- SELECT FROM users WHERE id = ?

**Flow:**
```
Test Client                    Flask App                    Database
     │                            │                            │
     │ POST /users                │                            │
     │ {username, email}          │                            │
     │───────────────────────────▶│                            │
     │                            │ INSERT INTO users          │
     │                            │───────────────────────────▶│
     │                            │                            │
     │                            │◀───────────────────────────│
     │ 201 Created                │ Return user with id        │
     │ {id, username, email}      │                            │
     │◀───────────────────────────│                            │
     │                            │                            │
     │ GET /users/{id}            │                            │
     │───────────────────────────▶│                            │
     │                            │ SELECT * FROM users        │
     │                            │ WHERE id = ?               │
     │                            │───────────────────────────▶│
     │                            │                            │
     │                            │◀───────────────────────────│
     │ 200 OK                     │ Return user data           │
     │ {same user data}           │                            │
     │◀───────────────────────────│                            │
```

---

#### Test: `test_create_user_duplicate_username`
**Purpose**: Verify unique constraint enforcement

**APIs Hit:**
- `POST /users` (twice) - Try to create duplicate

**Database Operations:**
- INSERT INTO users (first user) - SUCCESS
- INSERT INTO users (duplicate) - FAILS (unique constraint)

**Flow:**
```
Test Client                    Flask App                    Database
     │                            │                            │
     │ POST /users                │                            │
     │ {username: "john"}         │                            │
     │───────────────────────────▶│                            │
     │                            │ INSERT                     │
     │                            │───────────────────────────▶│
     │ 201 Created                │◀───────────────────────────│
     │◀───────────────────────────│ Success                    │
     │                            │                            │
     │ POST /users                │                            │
     │ {username: "john"}         │                            │
     │ (same username)            │                            │
     │───────────────────────────▶│                            │
     │                            │ INSERT                     │
     │                            │───────────────────────────▶│
     │ 409 Conflict               │◀───────────────────────────│
     │◀───────────────────────────│ IntegrityError             │
     │                            │                            │
```

---

#### Test: `test_update_user`
**Purpose**: Verify user modification and persistence

**APIs Hit:**
- `POST /users` - Create user
- `PUT /users/{id}` - Modify user

**Database Operations:**
- INSERT INTO users
- UPDATE users SET username = ? WHERE id = ?
- SELECT FROM users (verify update)

---

#### Test: `test_delete_user`
**Purpose**: Verify deletion removes data from DB

**APIs Hit:**
- `POST /users` - Create user
- `DELETE /users/{id}` - Delete user
- `GET /users/{id}` - Verify deletion

**Database Operations:**
- INSERT INTO users
- DELETE FROM users WHERE id = ?
- SELECT FROM users WHERE id = ? (returns empty)

---

### 2. URL API Integration Tests

#### Test: `test_create_short_url`
**Purpose**: Verify URL shortening with auto-generated code

**APIs Hit:**
- `POST /urls` - Create short URL

**Database Operations:**
- INSERT INTO urls (short_code, original_url, title)

**Verification:**
- Response contains `short_code` field
- `short_code` is 6 alphanumeric characters
- URL is persisted in database

---

#### Test: `test_create_url_with_user`
**Purpose**: Verify foreign key relationship between URL and User

**APIs Hit:**
- `POST /users` - Create user
- `POST /urls` - Create URL with user_id

**Database Operations:**
- INSERT INTO users
- INSERT INTO urls (with user_id foreign key)
- SELECT to verify relationship

**Flow:**
```
1. Create User → Returns user_id
2. Create URL with user_id → Returns URL with user_id
3. Verify URL.user_id matches created user
```

---

#### Test: `test_deactivate_url`
**Purpose**: Verify URL status modification

**APIs Hit:**
- `POST /urls` - Create URL
- `PUT /urls/{id}` - Deactivate URL

**Database Operations:**
- INSERT INTO urls (is_active = true)
- UPDATE urls SET is_active = false WHERE id = ?

---

### 3. Error Handling Integration Tests

#### Test: `test_404_not_found`
**Purpose**: Verify 404 responses for missing resources

**APIs Hit:**
- `GET /users/999999` - Non-existent user

**Database Operations:**
- SELECT FROM users WHERE id = 999999 (returns empty)

**Verification:**
- Status code: 404
- Response format: `{"error": "User not found"}`
- NOT a stack trace or HTML error page

---

#### Test: `test_invalid_json`
**Purpose**: Verify graceful handling of malformed requests

**APIs Hit:**
- `POST /users` with invalid JSON body

**Verification:**
- Status code: 400 or 415
- Response is JSON (not crash dump)
- Error message is helpful

---

#### Test: `test_missing_required_fields`
**Purpose**: Verify input validation

**APIs Hit:**
- `POST /users` with incomplete data

**Database Operations:**
- None (validation fails before DB)

---

### 4. Health Check Tests

#### Test: `test_health_status_code`
**Purpose**: Verify health endpoint returns 200

**APIs Hit:**
- `GET /health`

**Database Operations:**
- None (health check is stateless)

---

## Running Integration Tests

### Run all integration tests:
```bash
pytest tests/test_integration.py -v
```

### Run specific test:
```bash
pytest tests/test_integration.py::TestUserIntegration::test_create_and_get_user -v
```

### Run with coverage:
```bash
pytest tests/test_integration.py -v --cov=app
```

## Test Database Setup

Integration tests use **real PostgreSQL database** (not SQLite):

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: hackathon_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
```

**Why Real Database?**
- Tests actual SQL queries
- Verifies foreign key constraints
- Tests transaction behavior
- Catches ORM issues early

## CI/CD Integration

GitHub Actions runs integration tests automatically:

```yaml
- name: Run Integration Tests
  run: pytest tests/test_integration.py -v
```

**CI Flow:**
1. Start PostgreSQL service container
2. Install dependencies
3. Run migrations
4. Execute integration tests
5. Report results

## Debugging Failed Tests

### Check database state:
```bash
docker compose exec postgres psql -U postgres -d hackathon_db
\dt                    # List tables
SELECT * FROM users;   # Check data
```

### View test logs:
```bash
pytest tests/test_integration.py -v -s
```

### Run with debug output:
```bash
pytest tests/test_integration.py -v --tb=long
```

## Best Practices

1. **Use unique identifiers** - Avoid conflicts between tests
2. **Clean up after tests** - Database is cleaned automatically
3. **Test happy path AND error cases** - Both success and failure
4. **Verify database state** - Don't just check HTTP response
5. **Test edge cases** - Empty inputs, invalid formats, boundaries
