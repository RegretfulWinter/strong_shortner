# Frontend Live Demo Guide

A simple web UI for demonstrating error handling and Chaos Mode interactively.

## Access the Frontend

After starting the services:

```bash
docker compose up -d
```

Open in browser:
- Local: http://localhost:5001
- Server: http://45.63.124.31

## Live Demo Scenarios

### Scenario 1: User Registration & Login

**Demo Flow:**
1. Open http://localhost:5001
2. Enter email: `demo@example.com`
3. Click "Get Access Token"
4. **Show:** Success message and token generation

**Error Handling Demo:**
- Try empty email → Shows validation error
- Try invalid email format → Shows "Invalid email format" error

---

### Scenario 2: Create Short URL

**Demo Flow:**
1. After login, enter: `https://www.google.com/search?q=very+long+query+string`
2. Click "Create Short URL"
3. **Show:** Short URL created successfully

**Error Handling Demo:**
- Try empty URL → Shows "Missing required fields"
- Try invalid URL → Shows validation error
- Try while app is crashed → Shows "Service Unavailable"

---

### Scenario 3: Chaos Mode (Live Crash)

**Demo Flow:**
1. User is logged in and viewing their URLs
2. In terminal, kill the app:
   ```bash
   docker compose kill app
   ```
3. **Show Frontend:** User immediately sees connection error or "Service Unavailable"
4. **Show Recovery:** After auto-restart, user can refresh and continue

**What Judges See:**
- No stack trace exposed to user
- Clean error message in UI
- Service auto-recovers

---

### Scenario 4: Graceful 503 Error

**Demo Flow:**
1. Start with full stack (app + nginx):
   ```bash
   docker compose -f docker-compose.chaos-full.yml up -d
   ```
2. Access via Nginx: http://localhost:8080
3. Login and create some URLs
4. Kill app: `docker compose kill app`
5. **Show:** User gets JSON error `{"error": "Service Unavailable"}`
   instead of nginx error page or stack trace

---

## Technical Details

### Frontend Features
- **Pure HTML/CSS/JS** - No build step required
- **Responsive design** - Works on mobile and desktop
- **LocalStorage** - Persists login token
- **Real-time API calls** - Direct to backend

### Authentication
- Simple email-based login
- Auto-creates user if not exists
- API token stored in LocalStorage
- Token displayed in dashboard for API testing

### Error Handling UI
```javascript
// Frontend catches errors and shows user-friendly messages
try {
    const response = await fetch('/users', {...});
    if (!response.ok) {
        const error = await response.json();
        showError(error.error); // Shows: "Invalid email format"
    }
} catch (error) {
    showError("Service Unavailable"); // Network error
}
```

---

## Demo Checklist

| Feature | How to Demo | Expected Result |
|---------|-------------|-----------------|
| User Login | Enter email, click button | Dashboard appears with token |
| Create URL | Enter long URL | Short URL appears in list |
| 400 Error | Enter invalid email | Error message displayed |
| 404 Error | Try to access /user/99999 via API | JSON error returned |
| Chaos Mode | Kill app while user logged in | User sees error, then recovery |
| 503 Graceful | Kill app behind nginx | JSON "Service Unavailable" |

---

## Quick Test Commands

```bash
# Start services
docker compose up -d

# Open frontend
open http://localhost:5001

# Monitor logs during demo
docker compose logs -f app

# Kill app for chaos demo
docker compose kill app

# Check auto-restart
docker compose ps
```

---

## Screenshots for Documentation

1. **Login Page** - Clean form with email input
2. **Dashboard** - Token display + URL creation form
3. **Error Toast** - Red error message (validation)
4. **URL List** - Created short URLs with stats
5. **Chaos Mode** - Error shown during outage
6. **Recovery** - Dashboard working after restart
