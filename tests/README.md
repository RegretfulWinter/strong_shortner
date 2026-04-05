# Test Suite Documentation

## Overview

This directory contains all tests for the URL Shortener API. Tests are **detectable** by pytest and follow standard naming conventions.

## Test Structure

```
tests/
├── conftest.py              # Pytest fixtures and configuration
├── test_health.py           # Health endpoint tests
├── test_unit.py             # Unit tests for models and routes
├── test_integration.py      # Integration tests with real database
├── test_events.py           # Event API tests
└── load_test_simple.js      # Load testing with k6
```

## Test Discovery

Tests are automatically discovered by pytest based on naming conventions:

- **Files**: `test_*.py` (e.g., `test_unit.py`)
- **Classes**: `Test*` (e.g., `TestUserModel`)
- **Functions**: `test_*` (e.g., `test_create_user`)

## Running Tests

### Run all tests
```bash
pytest tests/
```

### Run specific test file
```bash
pytest tests/test_unit.py -v
pytest tests/test_integration.py -v
pytest tests/test_health.py -v
```

### Run with coverage
```bash
pytest tests/ --cov=app --cov-report=term
```

### List all tests (collect-only)
```bash
pytest tests/ --collect-only
```

## Test Categories

### 1. Unit Tests (`test_unit.py`)

**Purpose**: Test individual functions and models in isolation

**Coverage**:
- User model CRUD operations
- URL model operations  
- Event model creation
- Input validation

**Examples**:
- `test_user_creation` - Create user in database
- `test_url_deactivation` - Deactivate short URL
- `test_invalid_email_format` - Validate email format

### 2. Integration Tests (`test_integration.py`)

**Purpose**: Test API endpoints with real database operations

**Coverage**:
- User API (create, get, update, delete)
- URL API (create with user, deactivate)
- Error handling (404, 400, validation)
- Health endpoint

**Examples**:
- `test_create_and_get_user` - POST then GET
- `test_create_url_with_user` - Foreign key relationship
- `test_404_not_found` - Error response format

### 3. Health Tests (`test_health.py`)

**Purpose**: Test health check endpoint

**Coverage**:
- Health status code (200)
- Health response format
- Database connectivity check

### 4. Event Tests (`test_events.py`)

**Purpose**: Test event tracking API

**Coverage**:
- Event creation with URL/User
- Event filtering (by type, user, URL)
- Pagination

## Test Configuration

Configuration in `pytest.ini`:

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
```

## CI/CD Integration

Tests run automatically in GitHub Actions:

1. **List Tests**: Shows all discoverable tests
2. **Unit Tests**: Fast tests without external dependencies
3. **Integration Tests**: Tests with PostgreSQL database
4. **Coverage Report**: Code coverage analysis

## Detectability Checklist

- [x] Test files follow `test_*.py` naming
- [x] Test classes follow `Test*` naming  
- [x] Test functions follow `test_*` naming
- [x] `pytest.ini` configured correctly
- [x] Tests run in CI pipeline
- [x] Coverage reported
- [x] All tests listed in CI logs

## Adding New Tests

1. Create file: `test_<feature>.py`
2. Import pytest and fixtures from `conftest.py`
3. Define test functions with `test_` prefix
4. Run `pytest tests/ --collect-only` to verify detection
