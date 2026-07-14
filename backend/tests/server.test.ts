import request from 'supertest';
import { createServer } from '../src/platform/httpServer';

const app = createServer();

describe('backend skeleton (modular monolith composition root)', () => {
  it('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.version).toBe('1.1.0');
  });

  it('mounts each bounded-context router under /v1 (stubbed → 501)', async () => {
    // Endpoints exist (routed) but are not implemented yet.
    await request(app).post('/v1/auth/session').expect(501);
    await request(app).post('/v1/settlement/redeem').expect(501);
    await request(app).get('/v1/history').expect(501);
    await request(app).get('/v1/config').expect(501);
    // Note: /v1/wallet/load is implemented in Task 2, so it returns 400 (bad request) not 501.
  });

  it('returns 404 for unknown routes', async () => {
    await request(app).get('/v1/does-not-exist').expect(404);
  });
});
