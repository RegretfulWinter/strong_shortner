// Scalability Bronze: 50 Concurrent Users Load Test
// Usage: k6 run load_test.js

import http from 'k6/http';
import { check, sleep } from 'k6';

// Test configuration for 50 concurrent users
export const options = {
  stages: [
    { duration: '10s', target: 50 },  // Ramp up to 50 users over 10s
    { duration: '30s', target: 50 },  // Stay at 50 users for 30s
    { duration: '10s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // p95 should be under 500ms
    http_req_failed: ['rate<0.1'],      // Error rate should be < 10%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:5001';

export default function () {
  // Test health endpoint (most important for load balancer)
  const healthRes = http.get(`${BASE_URL}/health`);
  
  check(healthRes, {
    'health status is 200': (r) => r.status === 200,
    'health response time < 500ms': (r) => r.timings.duration < 500,
  });

  // Test users list
  const usersRes = http.get(`${BASE_URL}/users`);
  
  check(usersRes, {
    'users status is 200': (r) => r.status === 200,
  });

  // Test URLs list
  const urlsRes = http.get(`${BASE_URL}/urls`);
  
  check(urlsRes, {
    'urls status is 200': (r) => r.status === 200,
  });

  // Small sleep to mimic real user behavior
  sleep(1);
}

// Summary output for documentation
export function handleSummary(data) {
  console.log('\n=== SCALABILITY BRONZE TEST RESULTS ===');
  console.log(`Concurrent Users: 50`);
  console.log(`P95 Response Time: ${data.metrics.http_req_duration.values['p(95)']}ms`);
  console.log(`Error Rate: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  console.log(`Total Requests: ${data.metrics.http_reqs.values.count}`);
  console.log('=========================================\n');
  
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
