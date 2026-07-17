import { loadConfig } from '../src/platform/config';

/**
 * platform/config.ts (production hardening §4 "centralize configuration,
 * fail fast for missing production configuration"). Every case passes an
 * explicit env object — never mutates `process.env` — so this file needs no
 * reset/restore dance around global state.
 */
describe('loadConfig (production hardening §4)', () => {
  it('defaults to the local-dev database URL outside production', () => {
    const config = loadConfig({ NODE_ENV: 'development' });
    expect(config.databaseUrl).toContain('offline_wallet');
  });

  it('defaults to the test database URL under NODE_ENV=test', () => {
    const config = loadConfig({ NODE_ENV: 'test' });
    expect(config.databaseUrl).toContain('offline_wallet_test');
  });

  it('uses the test database under NODE_ENV=test even when a dev-pointed DATABASE_URL is set', () => {
    // Regression: a developer's local .env commonly sets DATABASE_URL to the
    // dev database (per .env.example). If that value won, `npm test`'s
    // beforeAll TRUNCATE (tests/setup/db_setup.ts) would silently wipe dev
    // data instead of the isolated test database.
    const config = loadConfig({
      NODE_ENV: 'test',
      DATABASE_URL: 'postgres://wallet:wallet@localhost:5432/offline_wallet',
    });
    expect(config.databaseUrl).toContain('offline_wallet_test');
  });

  it('fails fast when NODE_ENV=production and DATABASE_URL is not set', () => {
    expect(() => loadConfig({ NODE_ENV: 'production' })).toThrow(/DATABASE_URL/);
  });

  it('accepts an explicit DATABASE_URL in production', () => {
    const config = loadConfig({ NODE_ENV: 'production', DATABASE_URL: 'postgres://prod/db' });
    expect(config.databaseUrl).toBe('postgres://prod/db');
  });

  it('applies documented default risk limits (REQUIREMENTS.md FR-RSK)', () => {
    const config = loadConfig({ NODE_ENV: 'test' });
    expect(config.risk.maxOfflineWalletBalancePaise).toBe(50_000 * 100);
    expect(config.risk.maxSingleOfflinePaymentPaise).toBe(5_000 * 100);
    expect(config.risk.maxCumulativeOfflinePaise).toBe(50_000 * 100);
  });

  it('reads risk limits from the environment when set', () => {
    const config = loadConfig({ NODE_ENV: 'test', RISK_MAX_SINGLE_PAYMENT_PAISE: '123456' });
    expect(config.risk.maxSingleOfflinePaymentPaise).toBe(123456);
  });

  it('throws a clear error for a non-integer numeric env var', () => {
    expect(() => loadConfig({ NODE_ENV: 'test', RISK_MAX_SINGLE_PAYMENT_PAISE: 'not-a-number' })).toThrow(
      /RISK_MAX_SINGLE_PAYMENT_PAISE/,
    );
  });

  it('defaults log level to debug outside production and info in production', () => {
    expect(loadConfig({ NODE_ENV: 'development' }).logLevel).toBe('debug');
    expect(loadConfig({ NODE_ENV: 'production', DATABASE_URL: 'postgres://prod/db' }).logLevel).toBe('info');
  });

  it('reads an explicit LOG_LEVEL override', () => {
    expect(loadConfig({ NODE_ENV: 'test', LOG_LEVEL: 'warn' }).logLevel).toBe('warn');
  });

  it('applies default rate-limit configuration', () => {
    const config = loadConfig({ NODE_ENV: 'test' });
    expect(config.rateLimit.authMax).toBeGreaterThan(0);
    expect(config.rateLimit.generalMax).toBeGreaterThan(0);
  });
});
