#!/bin/bash
# Scalability Bronze: 50 Concurrent Requests to Single Endpoint
# Tests one endpoint with 50 simultaneous requests

API_URL="${API_URL:-http://localhost:5001}"
CONCURRENT=50

# Default endpoint: Create URL (can be overridden)
ENDPOINT="${1:-create_url}"

case $ENDPOINT in
    "create_url")
        URL="$API_URL/urls"
        METHOD="POST"
        ;;
    "register")
        URL="$API_URL/users"
        METHOD="POST"
        ;;
    "list_urls")
        URL="$API_URL/urls"
        METHOD="GET"
        ;;
    "health")
        URL="$API_URL/health"
        METHOD="GET"
        ;;
    *)
        echo "Unknown endpoint: $ENDPOINT"
        echo "Available: create_url, register, list_urls, health"
        exit 1
        ;;
esac

echo "=========================================="
echo "  SINGLE ENDPOINT CONCURRENT TEST - 50"
echo "  Endpoint: $ENDPOINT"
echo "  URL: $URL"
echo "  Method: $METHOD"
echo "=========================================="
echo ""

# Create temp directory
RESULTS_DIR=$(mktemp -d)
TEST_ID=$(date +%s%N)

echo "Preparing $CONCURRENT concurrent requests to $ENDPOINT..."
echo ""
echo "Starting in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo "🔥 FIRE! All 50 requests hitting $ENDPOINT now!"
echo ""

START_TIME=$(date +%s)

# Launch 50 concurrent requests to the same endpoint
for i in $(seq 1 $CONCURRENT); do
    temp_file="$RESULTS_DIR/req_${i}.txt"
    
    if [ "$METHOD" = "POST" ] && [ "$ENDPOINT" = "create_url" ]; then
        # Make each request unique to avoid conflicts
        unique_data="{\"original_url\": \"https://www.google.com/search?q=test${TEST_ID}${i}\", \"title\": \"Test $i\"}"
        curl -s -o /dev/null -w "%{http_code},%{time_total}" \
            -X POST "$URL" \
            -H "Content-Type: application/json" \
            -d "$unique_data" \
            > "$temp_file" 2>/dev/null &
    elif [ "$METHOD" = "POST" ] && [ "$ENDPOINT" = "register" ]; then
        unique_data="{\"username\": \"concurrent_${TEST_ID}_${i}\", \"email\": \"user_${TEST_ID}_${i}@test.com\"}"
        curl -s -o /dev/null -w "%{http_code},%{time_total}" \
            -X POST "$URL" \
            -H "Content-Type: application/json" \
            -d "$unique_data" \
            > "$temp_file" 2>/dev/null &
    else
        curl -s -o /dev/null -w "%{http_code},%{time_total}" \
            "$URL" \
            > "$temp_file" 2>/dev/null &
    fi
done

# Wait for all to complete
wait

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "All $CONCURRENT requests completed in ${TOTAL_DURATION}s"
echo ""

# Analyze results
echo "Analyzing results..."
echo ""

# Collect all results
count=0
success=0
times_file=$(mktemp)

for f in "$RESULTS_DIR/req_"*.txt; do
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

echo "=========================================="
echo "  RESULTS: $ENDPOINT ($CONCURRENT concurrent)"
echo "=========================================="
echo ""

if [ $count -eq 0 ]; then
    echo "❌ No results captured. Is the API running?"
    rm -rf "$RESULTS_DIR"
    rm -f "$times_file"
    exit 1
fi

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

# P99
p99_line=$(( count * 99 / 100 ))
[ $p99_line -lt 1 ] && p99_line=1
p99=$(sed -n "${p99_line}p" "$sorted_times")

# Average
avg=$(awk '{sum+=$1} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' "$sorted_times")

printf "Total Requests:    %d\n" $count
printf "Successful:        %d\n" $success
printf "Errors:            %d (%s%%)\n" $errors $error_rate
printf "Total Duration:    %ds\n" $TOTAL_DURATION
echo ""
printf "Response Times:\n"
printf "  Min:  %sms\n" "$min"
printf "  Avg:  %sms\n" "$avg"
printf "  P50:  %sms\n" "$p50"
printf "  P95:  %sms\n" "$p95"
printf "  P99:  %sms\n" "$p99"
printf "  Max:  %sms\n" "$max"

echo ""
echo "=========================================="
echo "  BRONZE EVALUATION"
echo "=========================================="
echo ""

# Check P95 < 500ms
p95_pass=$(echo "$p95 < 500" | bc 2>/dev/null)
if [ "$p95_pass" = "1" ]; then
    printf "P95 Latency: %sms\n" "$p95"
    echo "✅ P95 is under 500ms baseline"
else
    printf "P95 Latency: %sms\n" "$p95"
    echo "❌ P95 is over 500ms baseline"
fi

# Check error rate < 10%
error_pass=$(echo "$error_rate < 10" | bc 2>/dev/null)
if [ "$error_pass" = "1" ]; then
    printf "Error Rate: %s%%\n" "$error_rate"
    echo "✅ Error rate is under 10%"
else
    printf "Error Rate: %s%%\n" "$error_rate"
    echo "❌ Error rate is over 10%"
fi

echo ""
echo "=========================================="
echo ""

# Cleanup
rm -rf "$RESULTS_DIR"
rm -f "$times_file" "$sorted_times"
