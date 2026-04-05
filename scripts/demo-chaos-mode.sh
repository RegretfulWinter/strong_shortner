#!/bin/bash
# Chaos Mode Demo Script
# Demonstrates Docker auto-restart policy

set -e

API_URL="${API_URL:-http://localhost:80}"

echo "🔥 Chaos Mode Demo: Container Auto-Restart"
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Step 1: Check initial container status${NC}"
echo "----------------------------------------"
docker compose ps | grep app || echo "App container not running"
echo ""

echo -e "${BLUE}Step 2: Verify health endpoint is working${NC}"
echo "----------------------------------------"
INITIAL_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" || echo "000")
if [ "$INITIAL_HEALTH" = "200" ]; then
    echo -e "${GREEN}✅ Initial health check: OK (200)${NC}"
else
    echo -e "${RED}❌ Initial health check failed ($INITIAL_HEALTH)${NC}"
    echo "Make sure the app is running first!"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 3: KILL the app container! 💀${NC}"
echo "----------------------------------------"
echo "Executing: docker compose kill app"
docker compose kill app
echo -e "${RED}💀 Container killed at $(date)${NC}"
echo ""

echo -e "${BLUE}Step 4: Wait for auto-restart (5 seconds)...${NC}"
echo "----------------------------------------"
for i in {5..1}; do
    echo -n "$i..."
    sleep 1
done
echo ""
echo ""

echo -e "${BLUE}Step 5: Check container status after kill${NC}"
echo "----------------------------------------"
docker compose ps | grep app
echo ""

echo -e "${BLUE}Step 6: Verify container auto-restarted${NC}"
echo "----------------------------------------"
RETRY_COUNT=0
MAX_RETRIES=10

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" || echo "000")
    
    if [ "$HEALTH_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ Container auto-restarted successfully!${NC}"
        echo -e "${GREEN}✅ Health check passed (200) at $(date)${NC}"
        break
    else
        echo "Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES: Health check returned $HEALTH_STATUS, waiting..."
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Container failed to restart within expected time${NC}"
    exit 1
fi

echo ""
echo "============================================"
echo -e "${GREEN}✅ Chaos Mode Test PASSED!${NC}"
echo ""
echo "Summary:"
echo "--------"
echo "1. Container was running and healthy"
echo "2. Container was killed (simulated crash)"
echo "3. Docker auto-restarted the container"
echo "4. Health endpoint is responding again"
echo ""
echo "This demonstrates:"
echo "- Docker restart policy: unless-stopped"
echo "- Graceful recovery from crashes"
echo "- High availability design"
echo ""
echo "Production Impact:"
echo "- Downtime: ~5-10 seconds"
echo "- No manual intervention required"
echo "- Automatic recovery"
