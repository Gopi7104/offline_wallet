import request from 'supertest';

jest.mock('../src/platform/firebase', () => ({
  getFirebaseAuth: jest.fn(),
  isFirebaseCredentialConfigured: jest.fn(),
}));

// Imported after the mock so these bindings are the mocked functions.
import { getFirebaseAuth, isFirebaseCredentialConfigured } from '../src/platform/firebase';
import { createServer } from '../src/platform/httpServer';
import { resolveAccountId } from '../src/modules/identity/http/auth_middleware';

const mockGetFirebaseAuth = getFirebaseAuth as jest.Mock;
const mockIsFirebaseCredentialConfigured = isFirebaseCredentialConfigured as jest.Mock;
const mockVerifyIdToken = jest.fn();

/** Firebase-shaped errors carry a `.code`; production code branches on it. */
class FakeFirebaseAuthError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
  }
}

describe('Identity: Firebase Admin token verification (FR-ID-01)', () => {
  const ORIGINAL_NODE_ENV = process.env.NODE_ENV;
  let app: ReturnType<typeof createServer>;

  beforeEach(() => {
    process.env.NODE_ENV = ORIGINAL_NODE_ENV;
    mockGetFirebaseAuth.mockReturnValue({ verifyIdToken: mockVerifyIdToken });
    mockIsFirebaseCredentialConfigured.mockReturnValue(false);
    app = createServer();
  });

  afterAll(() => {
    process.env.NODE_ENV = ORIGINAL_NODE_ENV;
  });

  describe('POST /v1/auth/session', () => {
    it('exchanges a valid Firebase ID token for the account id (its UID)', async () => {
      mockVerifyIdToken.mockResolvedValueOnce({ uid: 'uid-abc', email: 'a@b.com' });

      const res = await request(app).post('/v1/auth/session').set('Authorization', 'Bearer valid-token');

      expect(res.status).toBe(200);
      expect(res.body.accountId).toBe('uid-abc');
      expect(res.body.firebaseUid).toBe('uid-abc');
      expect(res.body.email).toBe('a@b.com');
      expect(mockVerifyIdToken).toHaveBeenCalledWith('valid-token', false);
    });

    it('rejects a request with no Authorization header', async () => {
      const res = await request(app).post('/v1/auth/session');
      expect(res.status).toBe(401);
      expect(res.body.error).toBe('MISSING_TOKEN');
      expect(mockVerifyIdToken).not.toHaveBeenCalled();
    });

    it('rejects an invalid token', async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new FakeFirebaseAuthError('auth/argument-error', 'bad token'));

      const res = await request(app).post('/v1/auth/session').set('Authorization', 'Bearer garbage');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('INVALID_TOKEN');
    });

    it('rejects an expired token', async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new FakeFirebaseAuthError('auth/id-token-expired', 'expired'));

      const res = await request(app).post('/v1/auth/session').set('Authorization', 'Bearer expired-token');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('EXPIRED_TOKEN');
    });

    it('rejects a revoked token', async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new FakeFirebaseAuthError('auth/id-token-revoked', 'revoked'));

      const res = await request(app).post('/v1/auth/session').set('Authorization', 'Bearer revoked-token');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('REVOKED_TOKEN');
    });

    it('checks revocation only when a real credential is configured', async () => {
      mockIsFirebaseCredentialConfigured.mockReturnValue(true);
      mockVerifyIdToken.mockResolvedValueOnce({ uid: 'uid-prod' });

      await request(app).post('/v1/auth/session').set('Authorization', 'Bearer some-token');

      expect(mockVerifyIdToken).toHaveBeenCalledWith('some-token', true);
    });
  });

  describe('resolveAccountId middleware (mounted ahead of every /v1 route)', () => {
    it('resolves the account from a verified Firebase bearer token', async () => {
      mockVerifyIdToken.mockResolvedValueOnce({ uid: 'uid-wallet-1' });

      const res = await request(app).get('/v1/wallet').set('Authorization', 'Bearer valid-token');

      expect(res.body.accountId).toBe('uid-wallet-1');
    });

    it('rejects a malformed Authorization header (missing "Bearer " prefix)', async () => {
      const res = await request(app).get('/v1/wallet').set('Authorization', 'garbage-token');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('INVALID_AUTH_HEADER');
      expect(mockVerifyIdToken).not.toHaveBeenCalled();
    });

    it('rejects an empty bearer token', async () => {
      // Exercises resolveAccountId directly: an HTTP client (or intermediary)
      // may trim trailing whitespace from a header value in transit, so
      // driving this through supertest can't reliably deliver a literal
      // "Bearer " with nothing after it.
      const req = { headers: { authorization: 'Bearer ' } } as any;
      const json = jest.fn();
      const res = { status: jest.fn(() => ({ json })) } as any;
      const next = jest.fn();

      await resolveAccountId(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: 'MISSING_TOKEN' }));
      expect(next).not.toHaveBeenCalled();
      expect(mockVerifyIdToken).not.toHaveBeenCalled();
    });

    it('rejects an invalid bearer token with 401, not a fallback account', async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new FakeFirebaseAuthError('auth/argument-error', 'bad'));

      const res = await request(app).get('/v1/wallet').set('Authorization', 'Bearer garbage');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('INVALID_TOKEN');
    });

    it('rejects an expired bearer token with 401 on a protected route', async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new FakeFirebaseAuthError('auth/id-token-expired', 'expired'));

      const res = await request(app).get('/v1/wallet').set('Authorization', 'Bearer expired-token');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('EXPIRED_TOKEN');
    });

    describe('Guest Mode (development only)', () => {
      it('falls back to x-account-id when there is no Authorization header (non-production)', async () => {
        process.env.NODE_ENV = 'test';

        const res = await request(app).get('/v1/wallet').set('x-account-id', 'legacy-account');

        expect(res.body.accountId).toBe('legacy-account');
        expect(mockVerifyIdToken).not.toHaveBeenCalled();
      });

      it('falls back to the fixed test account when neither header is present (non-production)', async () => {
        process.env.NODE_ENV = 'development';

        const res = await request(app).get('/v1/wallet');

        expect(res.body.accountId).toBe('test-account-1');
      });

      it('prefers a verified bearer token over x-account-id when both are present', async () => {
        mockVerifyIdToken.mockResolvedValueOnce({ uid: 'uid-preferred' });

        const res = await request(app)
          .get('/v1/wallet')
          .set('Authorization', 'Bearer valid-token')
          .set('x-account-id', 'legacy-account');

        expect(res.body.accountId).toBe('uid-preferred');
      });

      it('is disabled in production: a missing Authorization header is rejected, not defaulted', async () => {
        process.env.NODE_ENV = 'production';

        const res = await request(app).get('/v1/wallet').set('x-account-id', 'legacy-account');

        expect(res.status).toBe(401);
        expect(res.body.error).toBe('MISSING_TOKEN');
      });
    });
  });
});
