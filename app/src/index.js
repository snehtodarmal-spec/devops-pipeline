const request = require('supertest');
const app = require('../src/index');

describe('App routes', () => {
  test('GET / returns status ok', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    
    // CHANGE THIS LINE from 'ok' to 'Success'
    expect(res.body.status).toBe('Success'); 
  });

  test('GET /health returns healthy', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.healthy).toBe(true);
  });
});

