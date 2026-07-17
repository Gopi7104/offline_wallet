import request from 'supertest';

// Real firebase-admin has an ESM-only transitive dependency ts-jest cannot
// parse (see platform/firebase.ts's own comment) — every other test file
// either never triggers `getFirebaseAuth()` or mocks this module first
// (auth.test.ts). The health check now calls it on every request, so this
// file needs the same mock.
jest.mock('../src/platform/firebase', () => ({
  getFirebaseAuth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
  isFirebaseCredentialConfigured: jest.fn(() => false),
}));

import { createServer } from '../src/platform/httpServer';

const app = createServer();

describe('backend skeleton (modular monolith composition root)', () => {
  it('GET /health returns ok, with database/firebase/issuerKey checks, uptime, and version', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.version).toBe('1.1.0');
    expect(typeof res.body.uptimeSeconds).toBe('number');
    expect(res.body.checks.database.status).toBe('ok');
    expect(res.body.checks.issuerKey.status).toBe('ok');
    // Mocked as not-configured (dev_mode) above — does not degrade overall status.
    expect(res.body.checks.firebase.status).toBe('dev_mode');
  });

  it('mounts the Identity/Risk routers (device registration + config, production hardening)', async () => {
    // Device registration validates its body (400), not a 501 stub anymore.
    await request(app).post('/v1/devices/register').send({}).expect(400);
    // Risk config is live — exposes the server-driven limits (FR-RSK-07).
    const config = await request(app).get('/v1/config');
    expect(config.status).toBe(200);
    expect(typeof config.body.risk.maxSingleOfflinePaymentPaise).toBe('number');
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

  it('returns 404 for unknown routes, with a consistent JSON error body', async () => {
    const res = await request(app).get('/v1/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NOT_FOUND');
    expect(typeof res.body.message).toBe('string');
  });

  it('GET /metrics returns basic operational counts (production hardening §7)', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(typeof res.body.totalWallets).toBe('number');
    expect(typeof res.body.activeMerchants).toBe('number');
    expect(typeof res.body.settlementsTotal).toBe('number');
    expect(typeof res.body.settlementsSucceeded).toBe('number');
    expect(typeof res.body.settlementsFailed).toBe('number');
    expect(typeof res.body.riskRejections).toBe('number');
  });
});
