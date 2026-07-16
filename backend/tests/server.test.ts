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
    await request(app).post('/v1/devices/register').expect(501);
    await request(app).get('/v1/config').expect(501);
    // Note: /v1/wallet/load is implemented in Task 2, so it returns 400 (bad request) not 501.
    // /v1/auth/session is implemented (FR-ID-01) — see auth.test.ts.
  });

  it('mounts the Settlement + Ledger routers (implemented in Task 9)', async () => {
    // Settlement rejects an empty body as a malformed payload (not 501/404).
    await request(app).post('/v1/settlement').send({}).expect(400);
    // Ledger read model is live (empty list before any settlement).
    const ledger = await request(app).get('/v1/ledger');
    expect(ledger.status).toBe(200);
    expect(Array.isArray(ledger.body.entries)).toBe(true);
  });

  it('returns 404 for unknown routes', async () => {
    await request(app).get('/v1/does-not-exist').expect(404);
  });
});
