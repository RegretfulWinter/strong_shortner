#!/bin/bash

# Graceful Failure Verification Script
# This script tests that the app returns clean JSON errors for bad inputs

API_URL="${API_URL:-http://45.63.124.31}"

echo "====================================="
echo "  Graceful Failure Verification"
echo "  API: $API_URL"
echo "====================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

passed=0
failed=0

# Test 1: Invalid email format
echo "Test 1: Invalid email format"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "not-an-email"}')
if echo "$response" | grep -q '"error"' && echo "$response" | grep -q "email"; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about email, got: $response"
    ((failed++))
fi
echo ""

# Test 2: Missing required fields
echo "Test 2: Missing required fields"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "test"}')
if echo "$response" | grep -q '"error"' && echo "$response" | grep -q "Missing"; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about missing fields, got: $response"
    ((failed++))
fi
echo ""

# Test 3: Invalid username (too short)
echo "Test 3: Invalid username (too short)"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "ab", "email": "test@example.com"}')
if echo "$response" | grep -q '"error"' && echo "$response" | grep -q "Username"; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error about username, got: $response"
    ((failed++))
fi
echo ""

# Test 4: Garbage JSON
echo "Test 4: Invalid JSON (garbage data)"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d 'this is not json')
if echo "$response" | grep -q '"error"'; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error for invalid JSON, got: $response"
    ((failed++))
fi
echo ""

# Test 5: Non-existent user
echo "Test 5: Request non-existent user (404)"
response=$(curl -s "$API_URL/users/999999")
if echo "$response" | grep -q '"error"' && echo "$response" | grep -q "not found"; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected 'not found' error, got: $response"
    ((failed++))
fi
echo ""

# Test 6: SQL injection attempt
echo "Test 6: SQL injection attempt (should not crash)"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"username": "test\' OR \'1\'=\'1", "email": "test@example.com"}')
if echo "$response" | grep -q '"error"'; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected validation error, got: $response"
    ((failed++))
fi
echo ""

# Test 7: Empty body
echo "Test 7: Empty request body"
response=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '')
if echo "$response" | grep -q '"error"'; then
    echo -e "${GREEN}✓ PASSED${NC}: $response"
    ((passed++))
else
    echo -e "${RED}✗ FAILED${NC}: Expected error for empty body, got: $response"
    ((failed++))
fi
echo ""

# Summary
echo "====================================="
echo "  Results: $passed passed, $failed failed"
echo "====================================="

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed! App handles bad inputs gracefully.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
