import rateLimit, { Options } from 'express-rate-limit';
import { Request, Response } from 'express';
import { sendError } from '../shared/http_errors';

/**
 * Rate limiting (production hardening §8). Sensitive endpoints — auth
 * session exchange, wallet load, settlement, merchant enable — get a
 * per-caller request budget; exceeding it returns 429.
 *
 * Keyed by the authenticated `req.accountId` (resolved by resolveAccountId
 * ahead of every /v1 route), not by IP: this is an authenticated API where
 * many real users legitimately share an IP (NAT, carrier-grade NAT, campus
 * wifi), and Firebase ID token verification already gates who can reach
 * these routes at all — throttling per-account is the meaningful unit of
 * abuse here. Falls back to `req.ip` only if a request somehow reaches a
 * limiter without an accountId resolved yet.
 */
function keyByAccount(req: Request): string {
  return req.accountId ?? req.ip ?? 'unknown';
}

function handler(res: Response): void {
  sendError(res, 429, 'RATE_LIMIT_EXCEEDED', 'Too many requests — try again shortly');
}

function makeLimiter(windowMs: number, max: number) {
  const options: Partial<Options> = {
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: keyByAccount,
    handler: (_req, res) => handler(res),
  };
  return rateLimit(options);
}

export function createAuthRateLimiter(windowMs: number, max: number) {
  return makeLimiter(windowMs, max);
}

export function createGeneralRateLimiter(windowMs: number, max: number) {
  return makeLimiter(windowMs, max);
}
