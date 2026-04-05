#!/bin/bash
# Chaos Mode: Kill the app PROCESS, show container auto-restarts
# Works without ps/pkill in container by using host docker commands

API_URL="${API_URL:-http://localhost:5001}"
COMPOSE_FILE="docker-compose.chaos.yml"

echo "🔥 Chaos Mode: Kill App Process & Auto-Restart"
echo "================================================="
echo ""
echo "Scenario: Kill PID 1 (gunicorn) inside container"
echo "          Container dies → Docker auto-restarts"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: Check initial state
echo -e "${BLUE}Step 1: Initial container state${NC}"
echo "----------------------------------------"
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

# Step 2: Verify app works
echo -e "${BLUE}Step 2: Verify app responding${NC}"
echo "----------------------------------------"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
if [ "$HEALTH" = "200" ]; then
    echo -e "${GREEN}✅ App healthy (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $HEALTH${NC}"
fi
echo ""

# Step 3: Get container ID and main PID
echo -e "${BLUE}Step 3: Container details${NC}"
echo "----------------------------------------"
CONTAINER_ID=$(docker compose -f "$COMPOSE_FILE" ps -q app)
echo "Container ID: $CONTAINER_ID"
MAIN_PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER_ID")
echo "Main PID (on host): $MAIN_PID"
echo ""

# Step 4: KILL the main process
echo -e "${RED}Step 4: KILL PID 1 (gunicorn) 💀${NC}"
echo "----------------------------------------"
echo "Sending SIGKILL to container's main process..."
docker kill --signal=SIGKILL "$CONTAINER_ID"
echo -e "${RED}💀 Process killed at $(date)${NC}"
echo ""

# Step 5: Show container stopped
echo -e "${YELLOW}Step 5: Container stopped${NC}"
echo "----------------------------------------"
sleep 2
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

# Step 6: Wait for auto-restart
echo -e "${YELLOW}Step 6: Wait for Docker auto-restart...${NC}"
echo "----------------------------------------"
echo "restart policy: always"
echo "Waiting"

RETRY=0
MAX_RETRY=30
while [ $RETRY -lt $MAX_RETRY ]; do
    # Check if new container is running
    NEW_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q app 2>/dev/null)
    if [ -n "$NEW_CONTAINER" ] && [ "$NEW_CONTAINER" != "$CONTAINER_ID" ]; then
        # New container with different ID
        STATUS=$(docker inspect --format '{{.State.Status}}' "$NEW_CONTAINER" 2>/dev/null)
        if [ "$STATUS" = "running" ]; then
            echo ""
            echo -e "${GREEN}✅ New container auto-started!${NC}"
            echo "   Old: ${CONTAINER_ID:0:12}"
            echo "   New: ${NEW_CONTAINER:0:12}"
            break
        fi
    fi
    # Also check if same container restarted
    STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID" 2>/dev/null)
    if [ "$STATUS" = "running" ]; then
        echo ""
        echo -e "${GREEN}✅ Container auto-restarted!${NC}"
        break
    fi
    echo -n "."
    sleep 1
    RETRY=$((RETRY + 1))
done

if [ $RETRY -eq $MAX_RETRY ]; then
    echo ""
    echo -e "${RED}❌ Auto-restart timeout${NC}"
    exit 1
fi

echo ""

# Step 7: Show new container
echo -e "${BLUE}Step 7: New container status${NC}"
echo "----------------------------------------"
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

# Step 8: Verify recovery
echo -e "${BLUE}Step 8: Verify app recovered${NC}"
echo "----------------------------------------"
sleep 3
RETRY=0
while [ $RETRY -lt 10 ]; do
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
    if [ "$HEALTH" = "200" ]; then
        echo -e "${GREEN}✅ App healthy (HTTP 200)${NC}"
        break
    fi
    echo "Waiting... ($HEALTH)"
    sleep 2
    RETRY=$((RETRY + 1))
done

echo ""
echo "================================================="
echo -e "${GREEN}✅ Chaos Mode Complete!${NC}"
echo "================================================="
echo ""
echo "What happened:"
echo "  1. App process (PID 1/gunicorn) running"
echo "  2. Killed main process 💀"
echo "  3. Container stopped"
echo "  4. Docker auto-restarted container ✅"
echo "  5. App back online"
echo ""
echo "Key point:"
echo "  'restart: always' in docker-compose.yml"
echo "  ensures auto-recovery from ANY crash"
