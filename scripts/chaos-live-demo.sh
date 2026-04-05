#!/bin/bash
# Live Demo: Chaos Mode with Auto-Restart
# For macOS Docker Desktop (with auto-restart simulation)

API_URL="${API_URL:-http://localhost:5001}"
COMPOSE_FILE="docker-compose.chaos.yml"

echo "🔥 Chaos Mode Live Demo"
echo "======================="
echo ""
echo "Kill app process → Container stops → Auto-restart → Service recovers"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure container is running
echo -e "${BLUE}1. Start services${NC}"
docker compose -f "$COMPOSE_FILE" up -d
sleep 3
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

# Check health
echo -e "${BLUE}2. Verify app working${NC}"
curl -s "$API_URL/health" | grep status
echo ""

# Show processes
echo -e "${BLUE}3. App processes${NC}"
echo "Main process: gunicorn (PID 1 in container)"
docker compose -f "$COMPOSE_FILE" top app 2>/dev/null | head -5 || echo "   gunicorn master + 4 workers"
echo ""

# Kill process
echo -e "${RED}4. 💀 KILL app process!${NC}"
CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q app)
docker kill --signal=SIGKILL "$CONTAINER"
echo "   Process killed"
echo ""

# Show stopped
echo -e "${YELLOW}5. Container stopped${NC}"
sleep 2
docker compose -f "$COMPOSE_FILE" ps | grep app || echo "   (container not running)"
echo ""

# Auto-restart
echo -e "${YELLOW}6. Auto-restarting...${NC}"
echo "   Docker Desktop macOS: Using watcher (Linux: restart:always works natively)"
RETRY=0
while [ $RETRY -lt 30 ]; do
    if docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo ""
        echo -e "${GREEN}   ✅ Restarted!${NC}"
        break
    fi
    docker compose -f "$COMPOSE_FILE" start app >/dev/null 2>&1
    echo -n "."
    sleep 1
    RETRY=$((RETRY + 1))
done
echo ""

# Show recovered
echo -e "${BLUE}7. New container${NC}"
docker compose -f "$COMPOSE_FILE" ps | grep app
echo ""

# Verify health
echo -e "${BLUE}8. Verify recovery${NC}"
sleep 3
curl -s "$API_URL/health" | grep status
echo ""

echo "======================="
echo -e "${GREEN}✅ Demo Complete!${NC}"
echo ""
echo "Summary:"
echo "  Process killed → Container stopped → Auto-restart → Service OK"
echo ""
echo "Configuration: docker-compose.yml"
echo "  restart: always  # Enables auto-recovery"
