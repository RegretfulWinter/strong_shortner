#!/bin/bash
# Scalability Bronze: Strict 50 Concurrent Users Test
# All 50 users hit the API at the exact same moment

API_URL="${API_URL:-http://localhost:5001}"
CONCURRENT=50

echo "=========================================="
echo "  STRICT CONCURRENT TEST - 50 USERS"
echo "  All hitting API at exact same second"
echo "=========================================="
echo ""
echo "API Endpoint: $API_URL/health"
echo "Concurrent Users: $CONCURRENT"
echo ""

# Create temp files
RESULTS_FILE=$(mktemp)
START_TIME_FILE=$(mktemp)

# Function for a single user hitting the API
user_request() {
    local user_id=$1
    local start_time=$(date +%s%N)
    
    # Make the request and capture timing
    local timing_info=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" \
        "$API_URL/health" 2>/dev/null)
    
    local end_time=$(date +%s%N)
    local total_time_ms=$(echo "scale=3; ($end_time - $start_time) / 1000000" | bc 2>/dev/null || echo "0")
    
    echo "$user_id,$timing_info,$total_time_ms" >> "$RESULTS_FILE"
}

export -f user_request
export API_URL RESULTS_FILE

echo "Preparing $CONCURRENT concurrent users..."
echo "All users will fire at the same moment!"
echo ""

# Wait for user to be ready
echo "Starting in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo "🔥 FIRE! All 50 users clicking now!"
echo ""

# Record start time
date +%s > "$START_TIME_FILE"

# Launch all 50 users at the exact same time
for i in $(seq 1 $CONCURRENT); do
    user_request $i &
done

# Wait for all to complete
wait

# Record end time
END_TIME=$(date +%s)
START_TIME=$(cat "$START_TIME_FILE")
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "All requests completed in ${TOTAL_DURATION} seconds"
echo ""

# Analyze results
echo "Analyzing results..."
echo ""

# Count results
TOTAL=$(wc -l < "$RESULTS_FILE" 2>/dev/null || echo "0")
if [ "$TOTAL" -eq 0 ]; then
    echo "❌ No results captured. Is the API running?"
    rm -f "$RESULTS_FILE" "$START_TIME_FILE"
    exit 1
fi

SUCCESS=$(grep -c ",200," "$RESULTS_FILE" 2>/dev/null || echo "0")
ERRORS=$((TOTAL - SUCCESS))
ERROR_RATE=$(echo "scale=2; ($ERRORS / $TOTAL) * 100" | bc -l 2>/dev/null || echo "0")

# Extract response times
echo "Response Time Distribution:"
echo "---------------------------"

# Parse response times (field 3 is total_time in ms)
awk -F',' '{print $3}' "$RESULTS_FILE" | sort -n > /tmp/response_times.txt

# Count for percentiles
COUNT=$(wc -l < /tmp/response_times.txt)

if [ "$COUNT" -gt 0 ]; then
    # Min and Max
    MIN=$(head -1 /tmp/response_times.txt)
    MAX=$(tail -1 /tmp/response_times.txt)
    
    # Calculate average using awk
    AVG=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' /tmp/response_times.txt)
    
    # Percentiles (1-indexed in head/tail)
    P50_LINE=$((COUNT * 50 / 100))
    P95_LINE=$((COUNT * 95 / 100))
    P99_LINE=$((COUNT * 99 / 100))
    [ "$P50_LINE" -eq 0 ] && P50_LINE=1
    [ "$P95_LINE" -eq 0 ] && P95_LINE=1
    [ "$P99_LINE" -eq 0 ] && P99_LINE=1
    
    P50=$(sed -n "${P50_LINE}p" /tmp/response_times.txt)
    P95=$(sed -n "${P95_LINE}p" /tmp/response_times.txt)
    P99=$(sed -n "${P99_LINE}p" /tmp/response_times.txt)
    
    echo "Min: ${MIN}ms"
    echo "Max: ${MAX}ms"
    echo "Avg: ${AVG}ms"
    echo "P50 (Median): ${P50}ms"
    echo "P95: ${P95}ms"
    echo "P99: ${P99}ms"
else
    echo "No timing data available"
    P95="0"
fi

echo ""
echo "Summary:"
echo "--------"
echo "Concurrent Users: $CONCURRENT"
echo "Total Requests: $TOTAL"
echo "Successful (HTTP 200): $SUCCESS"
echo "Errors: $ERRORS"
echo "Error Rate: ${ERROR_RATE}%"
echo "Total Duration: ${TOTAL_DURATION}s"
echo ""

# Determine pass/fail
echo "=========================================="
echo "  STRICT CONCURRENT TEST RESULTS"
echo "=========================================="
echo ""

# Check if P95 < 500ms
P95_CHECK=$(echo "$P95 < 500" | bc -l 2>/dev/null || echo "0")
if [ "$P95_CHECK" -eq 1 ]; then
    echo "✅ P95 Response Time: ${P95}ms (under 500ms)"
else
    echo "⚠️  P95 Response Time: ${P95}ms (over 500ms baseline)"
fi

echo "   BASELINE P95: ${P95}ms"

ERROR_CHECK=$(echo "$ERROR_RATE < 10" | bc -l 2>/dev/null || echo "0")
if [ "$ERROR_CHECK" -eq 1 ]; then
    echo "✅ Error Rate: ${ERROR_RATE}% (under 10%)"
else
    echo "⚠️  Error Rate: ${ERROR_RATE}% (over 10%)"
fi

echo ""
echo "=========================================="
echo ""

# Cleanup
rm -f "$RESULTS_FILE" "$START_TIME_FILE" /tmp/response_times.txt
