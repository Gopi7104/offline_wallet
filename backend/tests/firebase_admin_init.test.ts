/**
 * Tests platform/firebase.ts's own credential-resolution logic — separate
 * from auth.test.ts, which mocks this module entirely to test the auth
 * middleware/session endpoint in isolation. Here we mock `firebase-admin/app`
 * and `firebase-admin/auth` directly (never touching the real Admin SDK, or
 * network) and exercise the real ensureInitialized()/getFirebaseAuth() code.
 *
 * Each test resets the module registry so platform/firebase.ts's module-level
 * `app`/`credentialConfigured` state starts fresh — otherwise the singleton
 * from an earlier test would leak in.
 */
describe('platform/firebase: credential resolution', () => {
  const ORIGINAL_ENV = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...ORIGINAL_ENV };
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('fails fast with a clear error in production when no credentials are configured', () => {
    process.env.NODE_ENV = 'production';
    jest.doMock('firebase-admin/app', () => ({
      initializeApp: jest.fn(),
      cert: jest.fn(),
      applicationDefault: jest.fn(),
    }));
    jest.doMock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

    const { getFirebaseAuth } = require('../src/platform/firebase');

    expect(() => getFirebaseAuth()).toThrow(/Firebase Admin initialization failed/);
  });

  it('initializes in development mode without credentials, with a loud warning', () => {
    process.env.NODE_ENV = 'test';
    const initializeApp = jest.fn(() => ({ name: '[DEFAULT]' }));
    jest.doMock('firebase-admin/app', () => ({
      initializeApp,
      cert: jest.fn(),
      applicationDefault: jest.fn(),
    }));
    const getAuth = jest.fn(() => ({ verifyIdToken: jest.fn() }));
    jest.doMock('firebase-admin/auth', () => ({ getAuth }));

    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const { getFirebaseAuth, isFirebaseCredentialConfigured } = require('../src/platform/firebase');

    expect(() => getFirebaseAuth()).not.toThrow();
    expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('DEVELOPMENT mode'));
    expect(isFirebaseCredentialConfigured()).toBe(false);
    expect(initializeApp).toHaveBeenCalledWith({ projectId: 'offline-wallet-ab2fc' });

    warnSpy.mockRestore();
  });

  it('uses a service account from GOOGLE_APPLICATION_CREDENTIALS via applicationDefault()', () => {
    process.env.NODE_ENV = 'production';
    process.env.GOOGLE_APPLICATION_CREDENTIALS = '/tmp/fake-service-account.json';
    const initializeApp = jest.fn(() => ({ name: '[DEFAULT]' }));
    const applicationDefault = jest.fn(() => 'fake-application-default-credential');
    jest.doMock('firebase-admin/app', () => ({
      initializeApp,
      cert: jest.fn(),
      applicationDefault,
    }));
    jest.doMock('firebase-admin/auth', () => ({ getAuth: jest.fn(() => ({ verifyIdToken: jest.fn() })) }));

    const { getFirebaseAuth, isFirebaseCredentialConfigured } = require('../src/platform/firebase');

    expect(() => getFirebaseAuth()).not.toThrow();
    expect(applicationDefault).toHaveBeenCalled();
    expect(initializeApp).toHaveBeenCalledWith(
      expect.objectContaining({ credential: 'fake-application-default-credential' }),
    );
    expect(isFirebaseCredentialConfigured()).toBe(true);
  });

  it('uses an inline service account from FIREBASE_SERVICE_ACCOUNT_JSON via cert()', () => {
    process.env.NODE_ENV = 'production';
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = JSON.stringify({ project_id: 'offline-wallet-ab2fc' });
    const initializeApp = jest.fn(() => ({ name: '[DEFAULT]' }));
    const cert = jest.fn(() => 'fake-cert-credential');
    jest.doMock('firebase-admin/app', () => ({
      initializeApp,
      cert,
      applicationDefault: jest.fn(),
    }));
    jest.doMock('firebase-admin/auth', () => ({ getAuth: jest.fn(() => ({ verifyIdToken: jest.fn() })) }));

    const { getFirebaseAuth, isFirebaseCredentialConfigured } = require('../src/platform/firebase');

    expect(() => getFirebaseAuth()).not.toThrow();
    expect(cert).toHaveBeenCalledWith({ project_id: 'offline-wallet-ab2fc' });
    expect(initializeApp).toHaveBeenCalledWith(expect.objectContaining({ credential: 'fake-cert-credential' }));
    expect(isFirebaseCredentialConfigured()).toBe(true);
  });

  it('only initializes once — a second call reuses the same app', () => {
    process.env.NODE_ENV = 'test';
    const initializeApp = jest.fn(() => ({ name: '[DEFAULT]' }));
    jest.doMock('firebase-admin/app', () => ({
      initializeApp,
      cert: jest.fn(),
      applicationDefault: jest.fn(),
    }));
    jest.doMock('firebase-admin/auth', () => ({ getAuth: jest.fn(() => ({ verifyIdToken: jest.fn() })) }));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    const { getFirebaseAuth } = require('../src/platform/firebase');
    getFirebaseAuth();
    getFirebaseAuth();

    expect(initializeApp).toHaveBeenCalledTimes(1);
  });
});
