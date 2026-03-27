// ─────────────────────────────────────────────
// Jest + supertest unit tests for the Express app.
// Jenkins runs: npm test
// These must pass before SonarQube even gets called.
// ─────────────────────────────────────────────

const request = require('supertest');
const app = require('../src/index');

// Group related tests under a describe block.
// Jest will report these as a named suite in the
// console output — easy to read in Jenkins logs.
describe('App routes', () => {

  // Test 1: root route returns 200 and correct shape
  test('GET / returns status ok', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  // Test 2: health endpoint returns healthy: true
  // This is what a load balancer health check would call.
  test('GET /health returns healthy', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.healthy).toBe(true);
  });

});
