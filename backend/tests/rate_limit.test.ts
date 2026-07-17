import express from 'express';
import request from 'supertest';
import { createGeneralRateLimiter } from '../src/platform/rate_limit';

/**
 * platform/rate_limit.ts (production hardening §8). Tested against a tiny
 * standalone Express app (not the full composition root) so thresholds can
 * be set low and deterministic, independent of anything else in the app.
 */
function appWithLimiter(max: number, keyHeader = 'x-account-id') {
  const app = express();
  app.use((req, _res, next) => {
    // Stand-in for resolveAccountId — the limiter keys on req.accountId.
    const header = req.header(keyHeader);
    if (header !== undefined) {
      (req as express.Request & { accountId?: string }).accountId = header;
    }
    next();
  });
  app.use(createGeneralRateLimiter(60_000, max));
  app.get('/probe', (_req, res) => res.status(200).json({ ok: true }));
  return app;
}

describe('rate limiting (production hardening §8)', () => {
  it('allows requests up to the configured max', async () => {
    const app = appWithLimiter(3);
    for (let i = 0; i < 3; i++) {
      const res = await request(app).get('/probe').set('x-account-id', 'acct-1');
      expect(res.status).toBe(200);
    }
  });

  it('returns 429 with a standard error body once the max is exceeded', async () => {
    const app = appWithLimiter(2);
    await request(app).get('/probe').set('x-account-id', 'acct-1');
    await request(app).get('/probe').set('x-account-id', 'acct-1');
    const res = await request(app).get('/probe').set('x-account-id', 'acct-1');

    expect(res.status).toBe(429);
    expect(res.body.error).toBe('RATE_LIMIT_EXCEEDED');
    expect(typeof res.body.message).toBe('string');
  });

  it('tracks limits independently per account (one account being limited does not affect another)', async () => {
    const app = appWithLimiter(1);
    const first = await request(app).get('/probe').set('x-account-id', 'acct-a');
    expect(first.status).toBe(200);
    const limited = await request(app).get('/probe').set('x-account-id', 'acct-a');
    expect(limited.status).toBe(429);

    // A different account is unaffected by acct-a's limit.
    const other = await request(app).get('/probe').set('x-account-id', 'acct-b');
    expect(other.status).toBe(200);
  });
});
