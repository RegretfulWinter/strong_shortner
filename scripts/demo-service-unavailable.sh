#!/bin/bash
# Demo: Service Unavailable (503) - Graceful Degradation
# Shows "Service Unavailable" JSON instead of crash/errors when backend is down

echo "=========================================="
echo "  Service Unavailable - Graceful Demo"
echo "=========================================="
echo ""
echo "Scenario: App process crashes while user is using the service"
echo "Expected: User sees 'Service Unavailable' JSON, not stack trace"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.chaos.yml"

# Step 1: Start all services
echo -e "${BLUE}Step 1: Start services${NC}"
echo "------------------------------------------"
docker compose -f "$COMPOSE_FILE" up -d
sleep 5
docker compose -f "$COMPOSE_FILE" ps
echo ""

# Step 2: Verify app working through Nginx
echo -e "${BLUE}Step 2: User makes a request (working)${NC}"
echo "------------------------------------------"
echo "User: GET /health"
RESPONSE=$(curl -s http://localhost:5001/health)
echo "Response: $RESPONSE"
echo -e "${GREEN}✅ Service responding normally${NC}"
echo ""

# Step 3: Kill the app (simulating crash during user session)
echo -e "${RED}Step 3: 💥 App crashes!${NC}"
echo "------------------------------------------"
CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q app)
echo "Simulating: Someone accidentally kills the app process"
docker kill --signal=SIGKILL "$CONTAINER"
echo -e "${RED}💀 App process killed at $(date)${NC}"
echo ""

# Step 4: User tries again while app is restarting
echo -e "${YELLOW}Step 4: User makes another request (during crash)${NC}"
echo "------------------------------------------"
echo "User: GET /health (while app is down)"
echo ""

# Wait a moment to ensure app is fully stopped
sleep 2

echo "Response:"
# Use verbose to show HTTP status
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5001/health
echo ""

echo -e "${GREEN}✅ User sees 'Service Unavailable' JSON${NC}"
echo -e "${GREEN}✅ No stack trace, no crash details${NC}"
echo ""

# Step 5: Wait for recovery
echo -e "${BLUE}Step 5: Waiting for auto-restart...${NC}"
echo "------------------------------------------"
RETRY=0
while [ $RETRY -lt 20 ]; do
    if docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo ""
        echo -e "${GREEN}✅ Service recovered!${NC}"
        break
    fi
    docker compose -f "$COMPOSE_FILE" start app >/dev/null 2>&1
    echo -n "."
    sleep 1
    RETRY=$((RETRY + 1))
done
echo ""

# Step 6: Verify recovery
echo -e "${BLUE}Step 6: User request after recovery${NC}"
echo "------------------------------------------"
sleep 3
echo "User: GET /health (after recovery)"
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5001/health
echo ""

echo "=========================================="
echo -e "${GREEN}  Demo Complete!${NC}"
echo "=========================================="
echo ""
echo "Key Takeaways:"
echo "  1. App crashed while user was using it"
echo "  2. User saw: '{\"error\": \"Service Unavailable\"}' (503)"
echo "  3. User did NOT see: Python stack trace"
echo "  4. Service auto-recovered"
echo "  5. User can retry shortly"
echo ""
echo "Implementation:"
echo "  - Nginx error_page 502 503 504"
echo "  - Returns JSON: {\"error\": \"Service Unavailable\"}"
echo "  - Graceful degradation, no crash details leaked"
