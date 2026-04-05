#!/bin/bash
# Verify Docker Restart Policy Configuration
# This script demonstrates the restart policy setup for Chaos Mode

echo "==============================================="
echo "  Docker Restart Policy Verification"
echo "==============================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}1. Configuration in docker-compose.yml${NC}"
echo "--------------------------------------"
grep -A 1 "Chaos Mode\|restart:" docker-compose.yml | head -20
echo ""

echo -e "${BLUE}2. Running Container Restart Policies${NC}"
echo "--------------------------------------"
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps
echo ""

echo -e "${BLUE}3. Detailed App Container Policy${NC}"
echo "--------------------------------------"
if docker compose ps | grep -q app; then
    docker inspect $(docker compose ps -q app) --format '
Restart Policy: {{.HostConfig.RestartPolicy.Name}}
Max Retries: {{.HostConfig.RestartPolicy.MaximumRetryCount}}
' 2>/dev/null || echo "Container not running - start with: docker compose up -d app"
else
    echo "App container not running. Start with: docker compose up -d app"
fi
echo ""

echo -e "${BLUE}4. Documentation Reference${NC}"
echo "--------------------------------------"
echo "Docker Restart Policy: https://docs.docker.com/engine/containers/start-containers-automatically/"
echo "Our Choice: always"
echo "Reason: Ensures auto-restart even on manual stop (Chaos Mode requirement)"
echo ""

echo "==============================================="
echo -e "${GREEN}Verification Complete${NC}"
echo "==============================================="
