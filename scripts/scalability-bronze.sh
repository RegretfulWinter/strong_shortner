#!/bin/bash
# Scalability Bronze: 50 Concurrent Users Test
# This script runs a simple concurrent load test using curl

API_URL="${API_URL:-http://localhost:5001}"
CONCURRENT=50
TOTAL_REQUESTS=500

echo "=========================================="
echo "  SCALABILITY BRONZE TEST"
echo "  50 Concurrent Users Simulation"
echo "=========================================="
echo ""
echo "API Endpoint: $API_URL"
echo "Concurrent Users: $CONCURRENT"
echo "Total Requests: $TOTAL_REQUESTS"
echo ""

# Function to make a single request and measure time
make_request() {
    local start_time=$(date +%s%N)
    local response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" "$API_URL/health" 2>/dev/null)
    local end_time=$(date +%s%N)
    echo "$response"
}

export -f make_request
export API_URL

echo "Starting load test..."
echo ""

# Run concurrent requests using parallel processing
echo "Running $TOTAL_REQUESTS requests with $CONCURRENT concurrent connections..."

# Create temp file for results
TEMP_FILE=$(mktemp)

# Run requests in parallel
for i in $(seq 1 $TOTAL_REQUESTS); do
    (
        result=$(make_request)
        echo "$result" >> "$TEMP_FILE"
    ) &
    
    # Control concurrency
    if (( i % CONCURRENT == 0 )); then
        wait
    fi
done
wait

# Analyze results
echo ""
echo "Analyzing results..."
echo ""

TOTAL=$(wc -l < "$TEMP_FILE")
SUCCESS=$(grep -c "^200," "$TEMP_FILE" || echo "0")
ERRORS=$((TOTAL - SUCCESS))
ERROR_RATE=$(echo "scale=2; ($ERRORS / $TOTAL) * 100" | bc -l 2>/dev/null || echo "0")

# Calculate response times
echo "Response Time Distribution:"
echo "---------------------------"

# Extract response times and sort
cut -d',' -f2 "$TEMP_FILE" | sort -n > /tmp/response_times.txt

# Calculate percentiles
P50=$(awk 'BEGIN{RS="\n"; sum=0; count=0} {a[count++]=$1} END{print a[int(count*0.5)]}' /tmp/response_times.txt)
P95=$(awk 'BEGIN{RS="\n"; sum=0; count=0} {a[count++]=$1} END{print a[int(count*0.95)]}' /tmp/response_times.txt)
P99=$(awk 'BEGIN{RS="\n"; sum=0; count=0} {a[count++]=$1} END{print a[int(count*0.99)]}' /tmp/response_times.txt)

# Convert to milliseconds
P50_MS=$(echo "scale=2; $P50 * 1000" | bc 2>/dev/null || echo "N/A")
P95_MS=$(echo "scale=2; $P95 * 1000" | bc 2>/dev/null || echo "N/A")
P99_MS=$(echo "scale=2; $P99 * 1000" | bc 2>/dev/null || echo "N/A")

echo "P50 (Median): ${P50_MS}ms"
echo "P95: ${P95_MS}ms"
echo "P99: ${P99_MS}ms"
echo ""

echo "Summary:"
echo "--------"
echo "Total Requests: $TOTAL"
echo "Successful: $SUCCESS"
echo "Errors: $ERRORS"
echo "Error Rate: ${ERROR_RATE}%"
echo ""

# Cleanup
rm -f "$TEMP_FILE" /tmp/response_times.txt

echo "=========================================="
echo "  BASELINE P95 RESPONSE TIME: ${P95_MS}ms"
echo "=========================================="
echo ""

# Pass/Fail criteria
if (( $(echo "$P95 < 0.5" | bc -l 2>/dev/null || echo "0") )); then
    echo "✅ PASS: P95 is under 500ms"
else
    echo "⚠️  P95 is over 500ms baseline"
fi

if (( $(echo "$ERROR_RATE < 10" | bc -l 2>/dev/null || echo "0") )); then
    echo "✅ PASS: Error rate is under 10%"
else
    echo "⚠️  Error rate is over 10%"
fi
