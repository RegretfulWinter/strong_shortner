#!/bin/bash

# Graceful Failure Verification Script
# Tests that the app returns clean JSON errors for bad inputs

API_URL="${API_URL:-http://45.63.124.31}"

echo "====================================="
echo "  Graceful Failure Verification"
echo "  API: $API_URL"
echo "====================================="
echo ""
echo "Purpose: Send bad inputs → Get clean JSON errors (not crashes)"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

passed=0
failed=0

# Function to print test header
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Test $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print request details
print_request() {
    echo -e "${YELLOW}📤 REQUEST:${NC}"
    echo "  Method: $1"
    echo "  URL: $2"
    if [ -n "$3" ]; then
        echo "  Body: $3"
    fi
    echo ""
}

# Function to print response details
print_response() {
    echo -e "${GREEN}📥 RESPONSE:${NC}"
    echo "  Status: HTTP $1"
    echo "  Body: $2"
    echo ""
}

# Test 1: Invalid email format
print_header "1: Invalid Email Format"
method="POST"
url="$API_URL/users"
body='{"username": "test", "email": "not-an-email"}'
print_request "$method" "$url" "$body"

response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
  -H "Content-Type: application/json" \
  -d "$body")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if echo "$body_response" | grep -q '"error"' && echo "$body_response" | grep -q "email"; then
    echo -e "${GREEN}✓ PASSED${NC}: Clean JSON error returned"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about email format"
    ((failed++))
fi
echo ""

# Test 2: Missing required fields
print_header "2: Missing Required Fields"
method="POST"
url="$API_URL/users"
body='{"username": "test"}'
print_request "$method" "$url" "$body"

response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
  -H "Content-Type: application/json" \
  -d "$body")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if echo "$body_response" | grep -q '"error"' && echo "$body_response" | grep -q "Missing"; then
    echo -e "${GREEN}✓ PASSED${NC}: Clean JSON error returned"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about missing fields"
    ((failed++))
fi
echo ""

# Test 3: Invalid username (too short)
print_header "3: Invalid Username (Too Short)"
method="POST"
url="$API_URL/users"
body='{"username": "ab", "email": "test@example.com"}'
print_request "$method" "$url" "$body"

response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
  -H "Content-Type: application/json" \
  -d "$body")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if echo "$body_response" | grep -q '"error"' && echo "$body_response" | grep -q "username"; then
    echo -e "${GREEN}✓ PASSED${NC}: Clean JSON error returned"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about username"
    ((failed++))
fi
echo ""

# Test 4: Garbage JSON
print_header "4: Garbage/Invalid JSON"
method="POST"
url="$API_URL/users"
body='this is not json at all!!!'
print_request "$method" "$url" "$body"

response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
  -H "Content-Type: application/json" \
  -d "$body")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ PASSED${NC}: App returns 400 error without crashing"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected 400 error"
    ((failed++))
fi
echo ""

# Test 5: Non-existent user (404)
print_header "5: Non-existent User (404)"
method="GET"
url="$API_URL/users/999999"
print_request "$method" "$url" ""

response=$(curl -s -w "\n%{http_code}" "$url")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if echo "$body_response" | grep -q '"error"' && echo "$body_response" | grep -q "not found"; then
    echo -e "${GREEN}✓ PASSED${NC}: Clean JSON error returned"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected 'not found' error"
    ((failed++))
fi
echo ""

# Test 6: Very long input
print_header "6: Very Long Input (Buffer Test)"
method="POST"
url="$API_URL/users"
long_string=$(python3 -c "print('a' * 1000)")
body="{\"username\": \"$long_string\", \"email\": \"test@test.com\"}"
print_request "$method" "$url" '{"username": "'"$long_string"'", ...}'

response=$(curl -s -w "\n%{http_code}" --max-time 5 -X POST "$url" \
  -H "Content-Type: application/json" \
  -d "$body")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if echo "$body_response" | grep -q '"error"'; then
    echo -e "${GREEN}✓ PASSED${NC}: App validates input length, doesn't crash"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected validation error"
    ((failed++))
fi
echo ""

# Test 7: Empty body
print_header "7: Empty Request Body"
method="POST"
url="$API_URL/users"
print_request "$method" "$url" "(empty)"

response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
  -H "Content-Type: application/json" \
  -d '')
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ PASSED${NC}: App returns 400 without crashing"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected 400 error"
    ((failed++))
fi
echo ""

# Test 8: 500 Internal Server Error (Runtime Bug)
print_header "8: 500 Internal Server Error - Runtime Bug"
echo -e "${YELLOW}📝 SCENARIO:${NC} App encounters an unhandled exception"
echo -e "        (e.g., divide by zero, null pointer, type error)"
echo -e "        Should return clean JSON, not crash or expose stack trace"
echo ""

method="GET"
url="$API_URL/divide"
print_request "$method" "$url" ""

response=$(curl -s -w "\n%{http_code}" "$url")
http_code=$(echo "$response" | tail -n1)
body_response=$(echo "$response" | sed '$d')

print_response "$http_code" "$body_response"

# Check: returns 500 with clean JSON (no stack trace keywords)
if [ "$http_code" = "500" ]; then
    if echo "$body_response" | grep -q '"error"' && ! echo "$body_response" | grep -qi "traceback\|file\|line\|exception"; then
        echo -e "${GREEN}✓ PASSED${NC}: Clean JSON error (no stack trace exposed)"
        ((passed++))
    else
        echo -e "${RED}✗ FAILED${NC}: Stack trace or internal details leaked!"
        echo "  Response contains sensitive info."
        ((failed++))
    fi
else
    echo -e "${YELLOW}⚠ PARTIAL${NC}: Expected HTTP 500, got $http_code"
    echo "  (Error handler may not be working)"
    ((failed++))
fi
echo ""

# Summary
echo "====================================="
echo "  SUMMARY"
echo "====================================="
echo ""
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All $passed tests passed!${NC}"
    echo ""
    echo "✓ App handles bad inputs gracefully"
    echo "✓ Returns clean JSON errors (or 400 responses)"
    echo "✓ Never crashes on invalid input"
    exit 0
else
    echo -e "${RED}✗ Results: $passed passed, $failed failed${NC}"
    exit 1
fi
