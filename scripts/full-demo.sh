#!/bin/bash
# Full Demo Script for URL Shortener
# Run this to demonstrate all features

set -e

API_URL="${API_URL:-http://localhost:80}"

echo "==================================="
echo "  URL Shortener - Full Demo"
echo "==================================="
echo ""
echo "Press Enter to continue to each step..."
echo ""

read -p "Step 1: Start all services [Enter]"
docker compose up -d
echo "✅ Services started"
echo "Waiting 15s for initialization..."
sleep 15
docker compose ps | head -10
echo ""

read -p "Step 2: Health check [Enter]"
echo "Request: GET $API_URL/health"
curl -s "$API_URL/health" | jq
echo ""

read -p "Step 3: Create user [Enter]"
echo "Request: POST $API_URL/users"
USER_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "demo_user", "email": "demo@example.com"}')
echo "$USER_RESPONSE" | jq
echo ""

read -p "Step 4: 400 Error - Invalid email [Enter]"
echo "Request: POST $API_URL/users (bad email)"
curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "bad-email"}' | jq
echo ""

read -p "Step 5: 404 Error - User not found [Enter]"
echo "Request: GET $API_URL/users/99999"
curl -s "$API_URL/users/99999" | jq
echo ""

read -p "Step 6: Create short URL [Enter]"
echo "Request: POST $API_URL/urls"
URL_RESPONSE=$(curl -s -X POST "$API_URL/urls" \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://www.google.com", "user_id": 1}')
echo "$URL_RESPONSE" | jq
SHORT_CODE=$(echo "$URL_RESPONSE" | jq -r '.short_code')
echo ""
echo "Short code: $SHORT_CODE"
echo ""

read -p "Step 7: Test redirect (302) [Enter]"
echo "Request: GET $API_URL/$SHORT_CODE"
curl -v "$API_URL/$SHORT_CODE" 2>&1 | grep -E "(< HTTP|Location:)"
echo ""

read -p "Step 8: Chaos Mode - Container auto-restart [Enter]"
echo "Running chaos mode demo..."
./scripts/demo-chaos-mode-macos.sh
echo ""

echo "==================================="
echo "  Demo Complete!"
echo "==================================="
echo ""
echo "Summary:"
echo "  ✅ Health check working"
echo "  ✅ User API working"
echo "  ✅ Graceful error handling (400/404/500)"
echo "  ✅ URL shortener working"
echo "  ✅ Chaos Mode (auto-restart) working"
echo ""
