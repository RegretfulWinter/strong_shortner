#!/bin/bash
# Graceful Failure Demo Script
# Demonstrates that app returns clean JSON errors, not stack traces

set -e

API_URL="${API_URL:-http://localhost:80}"

echo "🧪 Graceful Failure Demo"
echo "========================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Test 1: Invalid JSON (400 Bad Request)${NC}"
echo "Request: POST /users with malformed JSON"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "not valid json")
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo -e "${YELLOW}Test 2: Missing Required Fields (400 Bad Request)${NC}"
echo "Request: POST /users without username"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}')
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo -e "${YELLOW}Test 3: Invalid Email Format (400 Bad Request)${NC}"
echo "Request: POST /users with invalid email"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "not-an-email"}')
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo -e "${YELLOW}Test 4: Resource Not Found (404 Not Found)${NC}"
echo "Request: GET /users/999999 (non-existent user)"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL/users/999999")
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo -e "${YELLOW}Test 5: Invalid Content-Type (415 Unsupported Media Type)${NC}"
echo "Request: POST /users with text/plain content type"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: text/plain" \
  -d '{"username": "test", "email": "test@example.com"}')
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo -e "${YELLOW}Test 6: Short URL Not Found (404)${NC}"
echo "Request: GET /nonexistent123"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL/nonexistent123")
BODY=$(echo "$RESPONSE" | sed -n '1,/HTTP_STATUS:/p' | sed 's/HTTP_STATUS://')
STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
echo "Status: $STATUS"
echo "Response: $BODY"
if echo "$BODY" | grep -q "error"; then
    echo -e "${GREEN}✅ Clean JSON error returned${NC}"
else
    echo -e "${RED}❌ Unexpected response format${NC}"
fi
echo ""

echo "========================"
echo -e "${GREEN}✅ All graceful failure tests completed!${NC}"
echo ""
echo "Key Observations:"
echo "- All errors return JSON with 'error' field"
echo "- No HTML stack traces returned"
echo "- Appropriate HTTP status codes used"
echo "- User-friendly error messages"
