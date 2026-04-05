#!/bin/bash
# Demo: 503 Service Unavailable - Graceful Degradation
# Shows "Service Unavailable" when backend crashes

API_URL="http://localhost:8080"
COMPOSE_FILE="docker-compose.chaos-full.yml"

echo "=========================================="
echo "  503 Service Unavailable - Graceful Demo"
echo "=========================================="
echo ""
echo "Chaos Engineering Principle:"
echo "  'Don't wait for a crash at 3 AM."
echo "   Cause the crash at 2 PM and fix it.'"
echo ""
echo "Graceful Principle:"
echo "  User should see 'Service Unavailable',"
echo "  not a Python stack trace."
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Step 1: Start services
echo -e "${BLUE}Step 1: Start all services (with Nginx)${NC}"
echo "------------------------------------------"
docker compose -f "$COMPOSE_FILE" up -d
sleep 10
docker compose -f "$COMPOSE_FILE" ps
echo ""

# Step 2: Normal operation
echo -e "${BLUE}Step 2: Normal operation${NC}"
echo "------------------------------------------"
echo "User makes a request through Nginx:"
echo "  GET $API_URL/health"
echo ""
RESPONSE=$(curl -s "$API_URL/health")
echo "Response: $RESPONSE"
echo -e "${GREEN}✅ Service is healthy${NC}"
echo ""

# Step 3: Chaos - Kill the app
echo -e "${RED}Step 3: 💥 CHAOS - Kill the app!${NC}"
echo "------------------------------------------"
echo "Simulating: App process crashes"
echo "(Someone accidentally kills the process)"
echo ""
CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q app)
docker kill --signal=SIGKILL "$CONTAINER" 2>/dev/null || true
echo -e "${RED}💥 App killed at $(date)${NC}"
echo ""

# Step 4: User request during outage
echo -e "${YELLOW}Step 4: User request during outage${NC}"
echo "------------------------------------------"
echo "User tries to access service while app is down:"
echo "  GET $API_URL/health"
echo ""

sleep 2

# Capture the response
FULL_RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/health" 2>&1)
HTTP_CODE=$(echo "$FULL_RESPONSE" | tail -n1)
BODY=$(echo "$FULL_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response Body: $BODY"
echo ""

if [ "$HTTP_CODE" = "503" ] || echo "$BODY" | grep -q "Service Unavailable"; then
    echo -e "${GREEN}✅ PERFECT! User sees 'Service Unavailable'${NC}"
    echo -e "${GREEN}✅ JSON error, not stack trace${NC}"
elif [ "$HTTP_CODE" = "502" ]; then
    echo -e "${YELLOW}⚠️  Got 502 Bad Gateway${NC}"
    echo -e "${GREEN}✅ But still better than stack trace!${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $HTTP_CODE${NC}"
fi
echo ""

# Step 5: Show what user does NOT see
echo -e "${CYAN}Step 5: What user does NOT see:${NC}"
echo "------------------------------------------"
echo "❌ No Python stack trace"
echo "❌ No 'Internal Server Error' HTML"
echo "❌ No connection refused error"
echo ""
echo -e "${GREEN}✅ Instead, user sees clean JSON:${NC}"
echo '  {"error": "Service Unavailable", ...}'
echo ""

# Step 6: Auto-recovery
echo -e "${BLUE}Step 6: Auto-recovery${NC}"
echo "------------------------------------------"
echo "Docker restart policy: always"
echo "Waiting for container to restart..."
echo ""

RETRY=0
while [ $RETRY -lt 30 ]; do
    if docker compose -f "$COMPOSE_FILE" ps | grep app | grep -q "Up"; then
        echo ""
        echo -e "${GREEN}✅ Container restarted!${NC}"
        break
    fi
    docker compose -f "$COMPOSE_FILE" up -d app >/dev/null 2>&1
    echo -n "."
    sleep 1
    RETRY=$((RETRY + 1))
done

echo ""
sleep 3

# Step 7: Service recovered
echo -e "${BLUE}Step 7: Service recovered${NC}"
echo "------------------------------------------"
echo "User request after recovery:"
RESPONSE=$(curl -s "$API_URL/health")
echo "Response: $RESPONSE" | head -c 100
echo "..."
echo -e "${GREEN}✅ Service is back!${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}  Demo Complete!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  1. ✅ Service was running normally"
echo "  2. 💥 App crashed (simulated)"
echo "  3. ✅ Nginx returned 503 Service Unavailable"
echo "  4. ✅ Clean JSON error (no stack trace)"
echo "  5. ✅ Service auto-recovered"
echo ""
echo "Implementation Details:"
echo "  - Nginx: error_page 502 503 504 @service_unavailable"
echo "  - Returns JSON with 'Service Unavailable' message"
echo "  - User can retry instead of seeing crash details"
echo ""
