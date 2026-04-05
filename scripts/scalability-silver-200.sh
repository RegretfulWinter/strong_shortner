#!/bin/bash
# Scalability Silver: 200 Concurrent Users with Horizontal Scaling
# Tests system with 2+ app instances behind Nginx load balancer

API_URL="${API_URL:-http://localhost}"
CONCURRENT=200

echo "=========================================="
echo "  SCALABILITY SILVER - THE HORDE"
echo "  200 Concurrent Users Attack"
echo "  Target: $API_URL"
echo "=========================================="
echo ""
echo "Requirements:"
echo "  - 200 concurrent users"
echo "  - 2+ app instances (horizontal scaling)"
echo "  - Nginx load balancer"
echo "  - Response time < 3 seconds"
echo ""

# Verify Docker setup
echo "Verifying infrastructure..."
echo ""

# Check if docker is available
if command -v docker &> /dev/null; then
    echo "Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "(app|nginx)" || echo "  (Not running - will use localhost)"
    echo ""
fi

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 3

# Create temp directory
RESULTS_DIR=$(mktemp -d)
TEST_ID=$(date +%s%N)

echo "Preparing $CONCURRENT concurrent requests..."
echo ""
echo "Starting in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo "🔥 THE HORDE ATTACKS! 200 users swarming the API!"
echo ""

START_TIME=$(date +%s)

# Function to make request and save result
make_request() {
    local i=$1
    local endpoint=$2
    local temp_file="$RESULTS_DIR/req_${i}.txt"
    
    case $endpoint in
        "create_url")
            unique_data="{\"original_url\": \"https://www.google.com/search?q=silver${TEST_ID}${i}\", \"title\": \"Silver Test $i\"}"
            curl -s -o /dev/null -w "%{http_code},%{time_total},create_url" \
                -X POST "$API_URL/urls" \
                -H "Content-Type: application/json" \
                -d "$unique_data" \
                > "$temp_file" 2>/dev/null
            ;;
        "list_urls")
            curl -s -o /dev/null -w "%{http_code},%{time_total},list_urls" \
                "$API_URL/urls" \
                > "$temp_file" 2>/dev/null
            ;;
        "health")
            curl -s -o /dev/null -w "%{http_code},%{time_total},health" \
                "$API_URL/health" \
                > "$temp_file" 2>/dev/null
            ;;
    esac
}

export -f make_request
export API_URL TEST_ID RESULTS_DIR

# Launch 200 concurrent requests - mixed workload
for i in $(seq 1 $CONCURRENT); do
    case $((i % 3)) in
        0) make_request $i "create_url" & ;;
        1) make_request $i "list_urls" & ;;
        2) make_request $i "health" & ;;
    esac
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
total_count=0
total_success=0
times_file=$(mktemp)

# Read each result file
for f in "$RESULTS_DIR"/req_*.txt; do
    if [ -f "$f" ] && [ -s "$f" ]; then
        content=$(cat "$f" 2>/dev/null)
        if [ -n "$content" ]; then
            http_code=$(echo "$content" | cut -d',' -f1)
            curl_time=$(echo "$content" | cut -d',' -f2)
            endpoint=$(echo "$content" | cut -d',' -f3)
            
            total_count=$((total_count + 1))
            if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
                total_success=$((total_success + 1))
            fi
            
            # Convert curl time (seconds) to ms
            if [ -n "$curl_time" ]; then
                time_ms=$(echo "$curl_time * 1000" | bc 2>/dev/null || echo "0")
                echo "$time_ms,$endpoint" >> "$times_file"
            fi
        fi
    fi
done

echo "=========================================="
echo "  SILVER RESULTS: 200 CONCURRENT USERS"
echo "=========================================="
echo ""

if [ $total_count -eq 0 ]; then
    echo "❌ No results captured. Is the API running?"
    rm -rf "$RESULTS_DIR"
    rm -f "$times_file"
    exit 1
fi

total_errors=$((total_count - total_success))
error_rate=$(echo "scale=2; ($total_errors * 100) / $total_count" | bc 2>/dev/null || echo "0")

# Overall percentiles
sorted_times=$(mktemp)
awk -F',' '{print $1}' "$times_file" | sort -n > "$sorted_times"

min=$(head -1 "$sorted_times")
max=$(tail -1 "$sorted_times")

# P50
p50_line=$(( (total_count + 1) / 2 ))
[ $p50_line -lt 1 ] && p50_line=1
p50=$(sed -n "${p50_line}p" "$sorted_times")

# P95
p95_line=$(( total_count * 95 / 100 ))
[ $p95_line -lt 1 ] && p95_line=1
p95=$(sed -n "${p95_line}p" "$sorted_times")

# P99
p99_line=$(( total_count * 99 / 100 ))
[ $p99_line -lt 1 ] && p99_line=1
p99=$(sed -n "${p99_line}p" "$sorted_times")

# Average
avg=$(awk '{sum+=$1} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' "$sorted_times")

printf "Total Requests:    %d\n" $total_count
printf "Successful:        %d\n" $total_success
printf "Failed:            %d\n" $total_errors
printf "Error Rate:        %s%%\n" $error_rate
printf "Total Duration:    %ds\n" $TOTAL_DURATION
echo ""
printf "Overall Response Times:\n"
printf "  Min:  %sms\n" "$min"
printf "  Avg:  %sms\n" "$avg"
printf "  P50:  %sms\n" "$p50"
printf "  P95:  %sms\n" "$p95"
printf "  P99:  %sms\n" "$p99"
printf "  Max:  %sms\n" "$max"

# Per-endpoint stats
echo ""
echo "Per-Endpoint Breakdown:"
echo "-----------------------"

for endpoint in "create_url" "list_urls" "health"; do
    endpoint_file=$(mktemp)
    grep ",$endpoint" "$times_file" | cut -d',' -f1 > "$endpoint_file"
    count=$(wc -l < "$endpoint_file" | tr -d ' ')
    
    if [ "$count" -gt 0 ]; then
        e_min=$(head -1 "$endpoint_file")
        e_max=$(tail -1 "$endpoint_file")
        e_avg=$(awk '{sum+=$1} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' "$endpoint_file")
        
        # P95 for endpoint
        e_p95_line=$(( count * 95 / 100 ))
        [ $e_p95_line -lt 1 ] && e_p95_line=1
        e_p95=$(sed -n "${e_p95_line}p" "$endpoint_file")
        
        printf "  %s: %d req, avg=%sms, p95=%sms\n" "$endpoint" "$count" "$e_avg" "$e_p95"
    fi
    rm -f "$endpoint_file"
done

echo ""
echo "=========================================="
echo "  SILVER EVALUATION"
echo "=========================================="
echo ""

# Check 1: P95 < 3000ms (3 seconds)
p95_pass=$(echo "$p95 < 3000" | bc 2>/dev/null)
if [ "$p95_pass" = "1" ]; then
    printf "✅ P95 Latency: %sms < 3000ms\n" "$p95"
else
    printf "❌ P95 Latency: %sms >= 3000ms\n" "$p95"
fi

# Check 2: Error rate < 10%
error_pass=$(echo "$error_rate < 10" | bc 2>/dev/null)
if [ "$error_pass" = "1" ]; then
    printf "✅ Error Rate: %s%% < 10%%\n" "$error_rate"
else
    printf "❌ Error Rate: %s%% >= 10%%\n" "$error_rate"
fi

# Check 3: Throughput
duration_float=$(echo "scale=2; $TOTAL_DURATION" | bc 2>/dev/null || echo "$TOTAL_DURATION")
if [ "$duration_float" != "0" ] && [ -n "$duration_float" ]; then
    rps=$(echo "scale=1; $total_count / $duration_float" | bc 2>/dev/null || echo "0")
    printf "📊 Throughput: %s req/sec\n" "$rps"
fi

echo ""
echo "=========================================="
echo ""

# Cleanup
rm -rf "$RESULTS_DIR"
rm -f "$times_file" "$sorted_times"
