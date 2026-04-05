# Backward Compatibility Note

## API Token Addition - Compatible with Existing Tests

### What Changed
- Added `api_token` field to `User` model
- Field is `null=True` (optional), so existing code works without changes

### Test Compatibility

✅ **All 50 existing tests pass without modification:**
- `test_unit.py` - 15 tests ✅
- `test_integration.py` - 14 tests ✅
- `test_events.py` - 19 tests ✅
- `test_health.py` - 2 tests ✅

### Why It Works

```python
# User model with optional api_token
api_token = CharField(unique=True, null=True)  # null=True = optional

# Existing tests continue to work:
User.create(username="test", email="test@example.com")  # api_token=null automatically

# New frontend can use token when needed:
user.generate_api_token()  # Creates token on demand
```

### Seed Users

Existing seed users (created on startup) don't have API tokens initially:
- `admin@example.com`
- `test1@example.com`
- `test2@example.com`

**They can still use the frontend** - the frontend generates a client-side token based on user ID and email.

### Frontend Authentication (No Password Needed)

The simple frontend uses email-based "login":

1. User enters email
2. System finds or creates user
3. Frontend generates a client-side token: `btoa(userId + email + timestamp)`
4. Token stored in LocalStorage
5. Used for subsequent API calls

**No password required** - this is a demo/development feature, not production security.

### For Production Use

If you need proper password authentication:

```python
# Add password field (future enhancement)
password_hash = CharField(null=True)  # Store hashed password

# Or use existing api_token as a simple auth mechanism:
# - User provides email
# - System returns api_token (like a password reset)
# - User stores token securely
```

### Database Migration

If deploying to existing database:

```sql
-- Peewee automatically handles this with null=True
-- Existing rows will have api_token = NULL
-- New rows can have api_token set or left NULL
```

No migration script needed - Peewee's `playhouse` handles schema changes automatically.

### Summary

| Aspect | Status |
|--------|--------|
| Existing tests | ✅ All 50 pass |
| Seed users | ✅ Work without modification |
| Frontend login | ✅ Email-based, no password needed |
| Database | ✅ Backward compatible (null=True) |
| API behavior | ✅ Unchanged |
