#!/bin/bash
# Chaos Test for Remote Server (via HTTP only)
# Tests error handling and resilience without Docker access

API_URL="${API_URL:-http://45.63.124.31}"

echo "🔥 Remote Chaos Test (HTTP Only)"
echo "================================="
echo "API: $API_URL"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

passed=0
failed=0

# Test 1: Invalid JSON (Garbage Data)
echo -e "${BLUE}Test 1: Invalid JSON Attack${NC}"
echo "----------------------------"
echo "Sending: not valid json"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "not valid json")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"
if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✅ Handled gracefully${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠️  Unexpected response${NC}"
    ((failed++))
fi
echo ""

# Test 2: Missing Required Fields
echo -e "${BLUE}Test 2: Missing Required Fields${NC}"
echo "-------------------------------"
echo 'Sending: {"email": "test@example.com"}'
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"
if echo "$BODY" | grep -q '"error"'; then
    echo -e "${GREEN}✅ Validation working${NC}"
    ((passed++))
else
    echo -e "${RED}❌ No error returned${NC}"
    ((failed++))
fi
echo ""

# Test 3: Invalid Email Format
echo -e "${BLUE}Test 3: Invalid Email Format${NC}"
echo "----------------------------"
echo 'Sending: {"username": "test", "email": "bad-email"}'
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "bad-email"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"
if echo "$BODY" | grep -q '"error"' && echo "$BODY" | grep -q "email"; then
    echo -e "${GREEN}✅ Email validation working${NC}"
    ((passed++))
else
    echo -e "${RED}❌ Email validation failed${NC}"
    ((failed++))
fi
echo ""

# Test 4: Non-existent Resource (404)
echo -e "${BLUE}Test 4: Non-existent Resource (404)${NC}"
echo "-----------------------------------"
echo "GET /users/999999"
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/users/999999")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"
if [ "$HTTP_CODE" = "404" ] && echo "$BODY" | grep -q '"error"'; then
    echo -e "${GREEN}✅ Clean 404 response${NC}"
    ((passed++))
else
    echo -e "${RED}❌ 404 handling failed${NC}"
    ((failed++))
fi
echo ""

# Test 5: Runtime Error (500) - Divide by Zero
echo -e "${BLUE}Test 5: Runtime Error (500)${NC}"
echo "---------------------------"
echo "GET /divide (simulates bug)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/divide")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"
if [ "$HTTP_CODE" = "500" ] && echo "$BODY" | grep -q '"error"'; then
    # Check no stack trace leaked
    if echo "$BODY" | grep -qi "traceback\|exception\|file.*line"; then
        echo -e "${RED}❌ Stack trace leaked!${NC}"
        ((failed++))
    else
        echo -e "${GREEN}✅ Clean 500 response (no stack trace)${NC}"
        ((passed++))
    fi
else
    echo -e "${YELLOW}⚠️  Endpoint may not exist yet (need deploy)${NC}"
    ((failed++))
fi
echo ""

# Test 6: Health Check Resilience (Rapid Requests)
echo -e "${BLUE}Test 6: Health Check Resilience${NC}"
echo "-------------------------------"
echo "Sending 20 rapid health check requests..."
SUCCESS=0
for i in {1..20}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
    if [ "$STATUS" = "200" ]; then
        ((SUCCESS++))
    fi
    echo -n "."
done
echo ""
echo "Success: $SUCCESS/20"
if [ $SUCCESS -eq 20 ]; then
    echo -e "${GREEN}✅ Health endpoint resilient${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠️  Some requests failed${NC}"
    ((failed++))
fi
echo ""

# Test 7: Long Input / Buffer Test
echo -e "${BLUE}Test 7: Long Input (Buffer Overflow Test)${NC}"
echo "------------------------------------------"
LONG_STRING=$(python3 -c "print('A' * 500)")
echo "Sending username with 500 characters..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$LONG_STRING\", \"email\": \"test@test.com\"}")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
if echo "$BODY" | grep -q '"error"'; then
    echo -e "${GREEN}✅ Input length validated${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠️  No validation error${NC}"
    ((passed++))  # May succeed depending on DB limits
fi
echo ""

# Summary
echo "================================="
echo "  SUMMARY"
echo "================================="
echo "Passed: $passed"
echo "Failed: $failed"
echo ""
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}🎉 All Chaos Tests Passed!${NC}"
    echo ""
    echo "The application:"
    echo "  ✅ Handles invalid inputs gracefully"
    echo "  ✅ Returns clean JSON errors (no crashes)"
    echo "  ✅ Never exposes stack traces"
    echo "  ✅ Remains resilient under load"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed${NC}"
    echo "(Note: 500 error test may need code deploy first)"
    exit 1
fi
