import { loadConfig } from './config';

/**
 * Structured logging (production hardening §3). Every log line is a single
 * JSON object — `{timestamp, level, event, ...fields}` — so log aggregators
 * can filter/query without regex-parsing free text (ARCHITECTURE.md §11
 * "structured, no secrets").
 *
 * SECURITY: `fields` values are redacted by KEY NAME before serialization —
 * any field whose name looks like a credential (secret, password, pin,
 * private key, authorization header, API key, credential — or `token`
 * itself, e.g. `token`/`idToken`/`accessToken`) is replaced with
 * `[REDACTED]` regardless of what the caller passed. This is defense-in-depth
 * on top of caller discipline: callers should still never pass raw
 * tokens/keys/PINs as log fields in the first place.
 *
 * Deliberately NOT a blanket `/token/i` substring match — this codebase logs
 * plenty of harmless `tokenId`/`tokenIds`/`tokenCount`-shaped fields (coin
 * identifiers and counts, not credentials) that must stay readable.
 */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVEL_ORDER: Record<LogLevel, number> = { debug: 0, info: 1, warn: 2, error: 3 };
const VALID_LEVELS: ReadonlySet<string> = new Set(['debug', 'info', 'warn', 'error']);

const SENSITIVE_KEY_PATTERN = /secret|password|pin|privatekey|private_key|authorization|apikey|api_key|credential/i;
// A key containing "token" is sensitive UNLESS it's a coin-identifier/count
// field (tokenId, tokenIds, tokenCount, acceptedTokenIds, ...) — those are
// safe and useful to log.
const TOKEN_LIKE_SAFE_SUFFIX = /token(id|ids|count)s?$/i;

function isSensitiveKey(key: string): boolean {
  if (SENSITIVE_KEY_PATTERN.test(key)) return true;
  return /token/i.test(key) && !TOKEN_LIKE_SAFE_SUFFIX.test(key);
}

function redact(fields: Record<string, unknown>): Record<string, unknown> {
  const safe: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    safe[key] = isSensitiveKey(key) ? '[REDACTED]' : value;
  }
  return safe;
}

let cachedMinLevel: LogLevel | undefined;

function minLevel(): LogLevel {
  if (!cachedMinLevel) {
    const configured = loadConfig().logLevel;
    cachedMinLevel = VALID_LEVELS.has(configured) ? (configured as LogLevel) : 'info';
  }
  return cachedMinLevel;
}

function write(level: LogLevel, event: string, fields: Record<string, unknown> = {}): void {
  if (LEVEL_ORDER[level] < LEVEL_ORDER[minLevel()]) return;
  const line = JSON.stringify({ timestamp: new Date().toISOString(), level, event, ...redact(fields) });
  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
}

export const logger = {
  debug: (event: string, fields?: Record<string, unknown>): void => write('debug', event, fields),
  info: (event: string, fields?: Record<string, unknown>): void => write('info', event, fields),
  warn: (event: string, fields?: Record<string, unknown>): void => write('warn', event, fields),
  error: (event: string, fields?: Record<string, unknown>): void => write('error', event, fields),
};
