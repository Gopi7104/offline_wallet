/**
 * platform/logger.ts (production hardening §3 "structured logging... never
 * log private keys, Firebase tokens, PINs, sensitive cryptographic
 * material"). Uses jest.resetModules() + a fresh require per test (mirroring
 * firebase_admin_init.test.ts's pattern) since the logger caches its
 * resolved minimum level at module scope from LOG_LEVEL.
 */
describe('logger (production hardening §3)', () => {
  const ORIGINAL_ENV = { ...process.env };
  let logSpy: jest.SpyInstance;
  let warnSpy: jest.SpyInstance;
  let errorSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...ORIGINAL_ENV };
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    logSpy.mockRestore();
    warnSpy.mockRestore();
    errorSpy.mockRestore();
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('emits a single-line JSON object with timestamp, level, and event', () => {
    process.env.LOG_LEVEL = 'debug';
    const { logger } = require('../src/platform/logger');
    logger.info('test.event', { foo: 'bar' });

    expect(logSpy).toHaveBeenCalledTimes(1);
    const parsed = JSON.parse(logSpy.mock.calls[0][0]);
    expect(parsed.level).toBe('info');
    expect(parsed.event).toBe('test.event');
    expect(parsed.foo).toBe('bar');
    expect(typeof parsed.timestamp).toBe('string');
  });

  it('redacts fields whose key name looks sensitive, regardless of value', () => {
    process.env.LOG_LEVEL = 'debug';
    const { logger } = require('../src/platform/logger');
    logger.info('test.event', {
      accountId: 'acct-1',
      token: 'super-secret-jwt',
      idToken: 'another-secret',
      accessToken: 'yet-another-secret',
      privateKey: 'ed25519-seed-hex',
      pin: '1234',
      password: 'hunter2',
      apiKey: 'abc123',
    });

    const parsed = JSON.parse(logSpy.mock.calls[0][0]);
    expect(parsed.accountId).toBe('acct-1');
    expect(parsed.token).toBe('[REDACTED]');
    expect(parsed.idToken).toBe('[REDACTED]');
    expect(parsed.accessToken).toBe('[REDACTED]');
    expect(parsed.privateKey).toBe('[REDACTED]');
    expect(parsed.pin).toBe('[REDACTED]');
    expect(parsed.password).toBe('[REDACTED]');
    expect(parsed.apiKey).toBe('[REDACTED]');
  });

  it('does NOT redact token-identifier/count fields (tokenId, tokenIds, tokenCount, acceptedTokenIds, ...)', () => {
    process.env.LOG_LEVEL = 'debug';
    const { logger } = require('../src/platform/logger');
    logger.info('test.event', {
      tokenId: 'tok-abc',
      tokenIds: ['tok-a', 'tok-b'],
      tokenCount: 3,
      acceptedTokenIds: ['tok-a'],
      rejectedTokenIds: [],
      duplicateTokenIds: [],
    });

    const parsed = JSON.parse(logSpy.mock.calls[0][0]);
    expect(parsed.tokenId).toBe('tok-abc');
    expect(parsed.tokenIds).toEqual(['tok-a', 'tok-b']);
    expect(parsed.tokenCount).toBe(3);
    expect(parsed.acceptedTokenIds).toEqual(['tok-a']);
    expect(parsed.rejectedTokenIds).toEqual([]);
    expect(parsed.duplicateTokenIds).toEqual([]);
  });

  it('routes warn/error to console.warn/console.error, info/debug to console.log', () => {
    process.env.LOG_LEVEL = 'debug';
    const { logger } = require('../src/platform/logger');
    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e');

    expect(logSpy).toHaveBeenCalledTimes(2); // debug + info
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(errorSpy).toHaveBeenCalledTimes(1);
  });

  it('suppresses levels below the configured minimum', () => {
    process.env.LOG_LEVEL = 'warn';
    const { logger } = require('../src/platform/logger');
    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e');

    expect(logSpy).not.toHaveBeenCalled();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(errorSpy).toHaveBeenCalledTimes(1);
  });

  it('falls back to info when LOG_LEVEL is not a recognized level', () => {
    process.env.LOG_LEVEL = 'verbose-nonsense';
    const { logger } = require('../src/platform/logger');
    logger.debug('d');
    logger.info('i');

    expect(logSpy).toHaveBeenCalledTimes(1); // only info, debug suppressed
  });
});
