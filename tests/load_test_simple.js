/*
 * Scalability Quest - Simple Load Test
 * Quick tests for Bronze/Silver/Gold tiers
 * 
 * Usage:
 *   k6 run --vus 50 --duration 60s tests/load_test_simple.js   # Bronze
 *   k6 run --vus 200 --duration 120s tests/load_test_simple.js # Silver
 *   k6 run --vus 500 --duration 180s tests/load_test_simple.js # Gold
 */

import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    // Silver requirement: 95% of requests under 3 seconds
    http_req_duration: ['p(95)<3000'],
    // Gold requirement: Less than 5% errors
    http_req_failed: ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:5000';

export default function () {
  // Test health endpoint
  let res = http.get(`${BASE_URL}/health`);
  check(res, {
    'health status is 200': (r) => r.status === 200,
    'health response time < 500ms': (r) => r.timings.duration < 500,
  });

  // Test list users
  res = http.get(`${BASE_URL}/users`);
  check(res, {
    'users status is 200': (r) => r.status === 200,
  });

  // Test list URLs
  res = http.get(`${BASE_URL}/urls`);
  check(res, {
    'urls status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
