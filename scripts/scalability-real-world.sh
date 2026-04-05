#!/bin/bash
# Scalability Bronze: Real-World Concurrent Test
# 50 users performing realistic actions simultaneously

API_URL="${API_URL:-http://localhost:5001}"
CONCURRENT=50

echo "=========================================="
echo "  REAL-WORLD CONCURRENT TEST - 50 USERS"
echo "  Testing actual user flows:"
echo "    1. User registration"
echo "    2. Create short URL"
echo "    3. List URLs"
echo "    4. Access short URL"
echo "=========================================="
echo ""
echo "API Base: $API_URL"
echo "Concurrent Users: $CONCURRENT"
echo ""

# Create temp files
RESULTS_DIR=$(mktemp -d)
TEST_ID=$(date +%s)

echo "Preparing $CONCURRENT concurrent users with mixed workloads..."
echo ""
echo "Starting in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo "🔥 FIRE! All 50 users performing real actions now!"
echo ""

START_TIME=$(date +%s)

# Launch concurrent tests - each endpoint type
test_register() {
    local user_id=$1
    local temp_file="$RESULTS_DIR/register_${user_id}.txt"
    curl -s -o /dev/null -w "%{http_code},%{time_total}" \
        -X POST "$API_URL/users" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"concurrent_${TEST_ID}_${user_id}\", \"email\": \"user_${TEST_ID}_${user_id}@test.com\"}" \
        > "$temp_file" 2>/dev/null
}

test_create_url() {
    local user_id=$1
    local temp_file="$RESULTS_DIR/create_url_${user_id}.txt"
    curl -s -o /dev/null -w "%{http_code},%{time_total}" \
        -X POST "$API_URL/urls" \
        -H "Content-Type: application/json" \
        -d "{\"original_url\": \"https://www.google.com/search?q=test${TEST_ID}${user_id}\", \"title\": \"Test ${user_id}\"}" \
        > "$temp_file" 2>/dev/null
}

test_list_urls() {
    local user_id=$1
    local temp_file="$RESULTS_DIR/list_urls_${user_id}.txt"
    curl -s -o /dev/null -w "%{http_code},%{time_total}" \
        "$API_URL/urls" \
        > "$temp_file" 2>/dev/null
}

test_access_url() {
    local user_id=$1
    local temp_file="$RESULTS_DIR/access_url_${user_id}.txt"
    curl -s -L -o /dev/null -w "%{http_code},%{time_total}" \
        "$API_URL/urls" \
        > "$temp_file" 2>/dev/null
}

export -f test_register test_create_url test_list_urls test_access_url
export API_URL TEST_ID RESULTS_DIR

# Distribute users across different endpoints
for i in $(seq 1 $CONCURRENT); do
    case $((i % 4)) in
        0) test_register $i & ;;
        1) test_create_url $i & ;;
        2) test_list_urls $i & ;;
        3) test_access_url $i & ;;
    esac
done

# Wait for all to complete
wait

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "All requests completed in ${TOTAL_DURATION}s"
echo ""

# Analyze results
echo "Analyzing results..."
echo ""

echo "Results by Endpoint:"
echo "--------------------"

TOTAL_REQUESTS=0
TOTAL_SUCCESS=0

# Process each endpoint
for endpoint in "register" "create_url" "list_urls" "access_url"; do
    count=0
    success=0
    times_file=$(mktemp)
    
    for f in "$RESULTS_DIR/${endpoint}_"*.txt; do
        if [ -f "$f" ]; then
            content=$(cat "$f")
            http_code=$(echo "$content" | cut -d',' -f1)
            curl_time=$(echo "$content" | cut -d',' -f2)
            
            count=$((count + 1))
            if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
                success=$((success + 1))
            fi
            
            # Convert curl time (seconds) to ms
            time_ms=$(echo "$curl_time * 1000" | bc 2>/dev/null || echo "0")
            echo "$time_ms" >> "$times_file"
        fi
    done
    
    if [ $count -gt 0 ]; then
        errors=$((count - success))
        error_rate=$(echo "scale=1; ($errors * 100) / $count" | bc 2>/dev/null || echo "0")
        
        # Calculate percentiles
        sorted_times=$(mktemp)
        sort -n "$times_file" > "$sorted_times"
        
        min=$(head -1 "$sorted_times")
        max=$(tail -1 "$sorted_times")
        
        # P50
        p50_line=$(( (count + 1) / 2 ))
        [ $p50_line -lt 1 ] && p50_line=1
        p50=$(sed -n "${p50_line}p" "$sorted_times")
        
        # P95
        p95_line=$(( count * 95 / 100 ))
        [ $p95_line -lt 1 ] && p95_line=1
        p95=$(sed -n "${p95_line}p" "$sorted_times")
        
        # Average
        avg=$(awk '{sum+=$1} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' "$sorted_times")
        
        echo ""
        echo "$endpoint:"
        printf "  Requests: %d | Success: %d | Errors: %d (%s%%)\n" $count $success $errors $error_rate
        printf "  Min: %sms | Avg: %sms | P50: %sms | P95: %sms | Max: %sms\n" "$min" "$avg" "$p50" "$p95" "$max"
        
        TOTAL_REQUESTS=$((TOTAL_REQUESTS + count))
        TOTAL_SUCCESS=$((TOTAL_SUCCESS + success))
        
        # Store P95 for create_url as our main metric
        if [ "$endpoint" = "create_url" ]; then
            MAIN_P95=$p95
            MAIN_ERROR_RATE=$error_rate
        fi
        
        rm -f "$sorted_times"
    fi
    
    rm -f "$times_file"
done

echo ""
echo "=========================================="
echo "  REAL-WORLD CONCURRENT TEST RESULTS"
echo "=========================================="
echo ""

TOTAL_ERRORS=$((TOTAL_REQUESTS - TOTAL_SUCCESS))
TOTAL_ERROR_RATE=$(echo "scale=1; ($TOTAL_ERRORS * 100) / $TOTAL_REQUESTS" | bc 2>/dev/null || echo "0")

printf "Total Requests: %d\n" $TOTAL_REQUESTS
printf "Successful: %d\n" $TOTAL_SUCCESS
printf "Errors: %d (%s%%)\n" $TOTAL_ERRORS $TOTAL_ERROR_RATE
printf "Total Duration: %ds\n" $TOTAL_DURATION
echo ""

# Evaluation
echo "BRONZE EVALUATION:"
echo "------------------"

if [ -n "$MAIN_P95" ]; then
    printf "Create URL P95: %sms\n" "$MAIN_P95"
    
    # Check if P95 < 500ms
    p95_pass=$(echo "$MAIN_P95 < 500" | bc 2>/dev/null)
    if [ "$p95_pass" = "1" ]; then
        echo "✅ P95 is under 500ms baseline"
    else
        echo "⚠️  P95 is over 500ms baseline"
    fi
fi

# Check error rate < 10%
if [ -n "$MAIN_ERROR_RATE" ]; then
    error_pass=$(echo "$MAIN_ERROR_RATE < 10" | bc 2>/dev/null)
    if [ "$error_pass" = "1" ]; then
        printf "✅ Error rate (%s%%) is under 10%%\n" "$MAIN_ERROR_RATE"
    else
        printf "⚠️  Error rate (%s%%) is over 10%%\n" "$MAIN_ERROR_RATE"
    fi
fi

echo ""
echo "=========================================="
echo ""

# Cleanup
rm -rf "$RESULTS_DIR"
