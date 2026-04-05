# About This Project

## The Story Behind URL Shortener

### What Inspired Me

> *"In production, hope is not a strategy."* — This quote from the hackathon briefing stuck with me.

I've always been fascinated by how large-scale systems like Twitter, Bitly, or GitHub handle millions of requests without breaking a sweat. When I saw the **Meta Production Engineering Hackathon**, I knew this was my chance to experience the chaos and beauty of building production-grade infrastructure.

The URL Shortener seemed deceptively simple—just take a long URL and return a short one, right? But as I dug deeper, I realized the real challenge wasn't the algorithm (base62 encoding is trivial), but **keeping the service alive when everything goes wrong**.

What truly inspired me was the idea of building something that could survive:
- A database going down at 3 AM
- A sudden traffic spike from a viral tweet  
- A deployment that breaks everything

### How I Built This Project

#### Phase 1: The Foundation (Reliability Quest)

I started with a minimal Flask application using Peewee ORM. The first lesson hit hard: **untested code is broken code**.

```python
# The naive approach (broken)
def create_short_url(long_url):
    short_code = generate_code()
    URL.create(short_code=short_code, original_url=long_url)  # What if duplicate?
    return short_code

# The production approach (fixed)
def create_short_url(long_url, user_id=None):
    for _ in range(MAX_RETRIES):
        short_code = generate_code()
        try:
            with db.atomic():  # Transaction safety
                return URL.create(
                    short_code=short_code, 
                    original_url=long_url,
                    user=user_id
                )
        except IntegrityError:
            continue  # Retry with new code
    raise RuntimeError("Failed to generate unique code")
```

I implemented comprehensive test coverage using **pytest**, achieving:
- **Unit tests** for model validation
- **Integration tests** for API endpoints  
- **Chaos tests** that randomly kill containers

The reliability quest taught me about **graceful degradation**—when the database is slow, return a 503 with a clear message instead of crashing.

#### Phase 2: The Scale Challenge (Scalability Quest)

This is where math became critical. I needed to understand:

$$\text{Throughput} = \frac{\text{Concurrent Users}}{\text{Average Response Time}}$$

With 50 concurrent users and a 500ms P95 requirement:

$$RPS_{required} = \frac{50}{0.5} = 100 \text{ requests/second}$$

My single Flask instance could handle ~80 RPS. To reach 200 concurrent users (Silver tier), I needed horizontal scaling:

$$
\text{Instances Needed} = \lceil \frac{\text{Target RPS}}{\text{RPS per Instance}} \rceil = \lceil \frac{400}{80} \rceil = 3
$$

I designed a **3-instance architecture** with Nginx as the load balancer:

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  User   │────▶│  Nginx  │────▶│  App 1  │     │   DB    │
└─────────┘     │ (LB)    │├────▶│  App 2  │────▶│         │
                │         │├────▶│  App 3  │     └─────────┘
                └─────────┘     └─────────┘
```

Using **least_conn** algorithm instead of round-robin prevented the "thundering herd" problem when one instance was slow.

**Load Testing Results:**

| Tier | Users | P95 Latency | Error Rate | Instances |
|------|-------|-------------|------------|-----------|
| Bronze | 50 | $274ms$ | $0\%$ | 1 |
| Silver | 200 | $1092ms$ | $0\%$ | 3 |

$$\text{Speedup} = \frac{200}{50} = 4\times \text{ capacity with } 3\times \text{ instances}$$

Not perfectly linear (due to database contention), but close!

#### Phase 3: Observability (Incident Response Quest)

The most eye-opening phase. I realized that **you can't fix what you can't see**.

I implemented structured JSON logging:

```json
{
  "timestamp": "2026-04-05T16:27:09.376Z",
  "level": "ERROR",
  "component": "Database",
  "msg": "Connection timeout",
  "function": "init_db",
  "trace_id": "abc-123-xyz"
}
```

And built a Prometheus metrics pipeline:

$$
\text{Error Rate} = \frac{\sum \text{requests}_{5xx}}{\sum \text{requests}_{total}} \times 100\%$$

The `/metrics` endpoint exposes:
- CPU usage: $\frac{\Delta \text{cpu\_seconds}}{\Delta t}$
- Memory: $\text{resident\_memory\_bytes}$
- Request latency histograms

### What I Learned

#### Technical Lessons

1. **The "Fallacies of Distributed Computing" are real**
   - The network is *not* reliable
   - Latency is *not* zero
   - Bandwidth is *not* infinite

2. **Database connections are precious**
   Without connection pooling, my app crashed at 100 concurrent users. Using Peewee's `db.atomic()` and proper connection management fixed this.

3. **Metrics drive decisions**
   Before adding metrics, I was guessing about performance. After seeing P95 latency spike to $2.5s$ during database writes, I knew exactly where to optimize.

#### Engineering Mindset

> *"Every system is distributed, even if it runs on one machine."*

I learned to design for failure:
- **Circuit breakers**: Stop calling a failing service
- **Retries with backoff**: $2^n$ seconds between retries
- **Graceful degradation**: Return cached data if fresh data fails

### Challenges I Faced

#### Challenge 1: The Prometheus Metrics Conflict

**Problem**: Unit tests failed with `ValueError: Duplicated timeseries in CollectorRegistry`.

**Root Cause**: Prometheus client uses a global registry. When `create_app()` was called multiple times in tests, metrics were registered twice.

**Solution**: 
```python
try:
    app_info = Info('app_info', 'URL Shortener Application')
except ValueError:
    # Metric already exists (in tests)
    pass
```

This taught me about **global state management** in Python and the importance of idempotent initialization.

#### Challenge 2: Nginx Rate Limiting

**Problem**: My 200-user load test showed 44% error rate. All requests were returning 503.

**Investigation**:
```bash
# Check nginx logs
docker logs nginx | grep "limit"
# Output: "limiting requests, excess: 10.000"
```

**Root Cause**: Nginx `limit_req_zone` was set to $10r/s$ per IP. With 200 concurrent users from localhost (same IP), most were rejected.

**Solution**: 
```nginx
# Increased for load testing
limit_req_zone $binary_remote_addr zone=api:10m rate=1000r/s;
```

**Lesson**: Infrastructure constraints can masquerade as application bugs.

#### Challenge 3: Docker Container Hell

**Problem**: After multiple rebuilds, orphaned containers caused network conflicts.

```bash
# The nightmare
docker ps
# app1-1, app1-1 (duplicate!), app2-1, app3-1, nginx-1...
```

**Root Cause**: Docker Compose didn't clean up old containers when switching branches.

**Solution**: A ritual I now perform before every test:
```bash
docker compose down --remove-orphans
docker network prune -f
docker compose up -d --build
```

#### Challenge 4: The `/metrics` Routing Conflict

**Problem**: Short URL redirect `/<short_code>` matched `/metrics`, returning "URL not found".

**Root Cause**: Flask routes are matched in order, and `/<string:short_code>` was too greedy.

**Solution**: Created a custom URL converter:
```python
class ShortCodeConverter(BaseConverter):
    regex = r'[a-zA-Z0-9]{6,}'  # Requires 6+ chars
    
    def to_python(self, value):
        system_paths = {'metrics', 'health', 'api'}
        if value.lower() in system_paths:
            raise ValueError("Reserved path")
        return value
```

This taught me about **Flask's URL routing internals** and the importance of strict validation.

### The Mathematical Beauty

Throughout this project, I kept coming back to one equation—the **Little's Law** from queueing theory:

$$L = \lambda \times W$$

Where:
- $L$ = average number of requests in system
- $\lambda$ = average arrival rate (requests/second)
- $W$ = average time a request spends in system

If 200 users send requests every 2 seconds ($\lambda = 100$), and each takes 1 second to process ($W = 1$), then:

$$L = 100 \times 1 = 100 \text{ concurrent requests}$$

This validated why my 3-instance setup (each handling ~80 concurrent connections) was sufficient for Silver tier.

### Conclusion

This hackathon transformed how I think about software engineering. Before, I focused on making code *work*. Now, I focus on making code *survive*.

The URL Shortener isn't just a CRUD app—it's a lesson in:
- **Resilience**: Handling failure gracefully
- **Scalability**: Horizontal scaling with $O(1)$ complexity
- **Observability**: Metrics, logs, and traces that tell stories

And most importantly, I learned that **production engineering is the art of expecting the unexpected**.

---

*Built with 💜, ☕, and a lot of `docker logs` during the Meta PE Hackathon 2026.*
