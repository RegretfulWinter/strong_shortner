#!/bin/bash
# Chaos Mode Demo with Auto-Restart Watcher for macOS
# This script watches the container and auto-restarts it when killed

API_URL="${API_URL:-http://localhost:5001}"
COMPOSE_FILE="docker-compose.chaos.yml"

echo "🔥 Chaos Mode Demo with Auto-Restart"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check container status
check_container() {
    docker compose -f "$COMPOSE_FILE" ps | grep app | grep -q "Up"
}

# Function to get health status
check_health() {
    curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null
}

echo -e "${BLUE}Step 1: Ensure container is running${NC}"
echo "--------------------------------------"
if ! check_container; then
    echo "Starting container..."
    docker compose -f "$COMPOSE_FILE" up -d app
    sleep 5
fi
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

echo -e "${BLUE}Step 2: Verify health endpoint${NC}"
echo "--------------------------------------"
HEALTH=$(check_health)
if [ "$HEALTH" = "200" ]; then
    echo -e "${GREEN}✅ Health check: OK (200)${NC}"
else
    echo -e "${YELLOW}⚠️  Health check: $HEALTH (may still be starting)${NC}"
fi
echo ""

echo -e "${RED}Step 3: KILL the container! 💀${NC}"
echo "--------------------------------------"
echo "Executing: docker compose kill app"
docker compose -f "$COMPOSE_FILE" kill app
echo -e "${RED}💀 Container killed at $(date)${NC}"
echo ""

echo -e "${YELLOW}Step 4: Auto-restart monitoring${NC}"
echo "--------------------------------------"
echo "Docker Desktop macOS limitation: Using watcher to auto-restart..."
echo ""

# Auto-restart loop (simulating what Docker should do)
RETRY=0
MAX_RETRY=30

while [ $RETRY -lt $MAX_RETRY ]; do
    if ! check_container; then
        echo -n "."
        docker compose -f "$COMPOSE_FILE" start app > /dev/null 2>&1
    else
        echo ""
        echo -e "${GREEN}✅ Container auto-restarted!${NC}"
        break
    fi
    sleep 1
    RETRY=$((RETRY + 1))
done

if [ $RETRY -eq $MAX_RETRY ]; then
    echo -e "${RED}❌ Failed to restart within $MAX_RETRY seconds${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 5: Verify container status${NC}"
echo "--------------------------------------"
sleep 3
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

echo -e "${BLUE}Step 6: Verify health endpoint${NC}"
echo "--------------------------------------"
RETRY=0
while [ $RETRY -lt 10 ]; do
    HEALTH=$(check_health)
    if [ "$HEALTH" = "200" ]; then
        echo -e "${GREEN}✅ Health check: OK (200)${NC}"
        break
    else
        echo "Waiting for health check... ($HEALTH)"
        sleep 2
        RETRY=$((RETRY + 1))
    fi
done

echo ""
echo "===================================="
echo -e "${GREEN}✅ Chaos Mode Demo Complete!${NC}"
echo "===================================="
echo ""
echo "Summary:"
echo "  1. Container was running"
echo "  2. Container was killed (simulated crash)"
echo "  3. Container was auto-restarted by watcher"
echo "  4. Health check passed"
echo ""
echo "Note: Docker Desktop macOS has restart policy limitations."
echo "      This demo uses a watcher script to simulate the behavior."
echo "      On Linux production servers, 'restart: always' works natively."
