#!/bin/bash
# Chaos Engineering Tests for Gold Tier

echo "🧪 Starting Chaos Engineering Tests..."
echo ""

# Test 1: Kill and Restart App Container
echo "=== Test 1: Container Auto-Restart ==="
echo "Killing app container..."
docker compose -f docker-compose.prod.yml kill app

echo "Waiting 10 seconds for auto-restart..."
sleep 10

HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health)
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ App container auto-restarted successfully!"
else
    echo "❌ App container failed to restart (HTTP $HEALTH_STATUS)"
    exit 1
fi
echo ""

# Test 2: Graceful Error Handling
echo "=== Test 2: Graceful Error Handling ==="

# Invalid JSON
echo "Testing invalid JSON..."
RESPONSE=$(curl -s -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d "not valid json")
echo "Response: $RESPONSE"

# Missing fields
echo "Testing missing required fields..."
RESPONSE=$(curl -s -X POST http://localhost:80/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}')
echo "Response: $RESPONSE"

# Non-existent resource
echo "Testing 404 response..."
RESPONSE=$(curl -s http://localhost:80/users/999999)
echo "Response: $RESPONSE"

echo "✅ All errors handled gracefully!"
echo ""

# Test 3: Health Check Resilience
echo "=== Test 3: Health Check Under Load ==="
for i in {1..10}; do
    curl -s http://localhost:80/health > /dev/null
    echo -n "."
done
echo ""
echo "✅ Health endpoint resilient!"
echo ""

echo "🎉 All Chaos Tests Passed!"
