import { Request, Response, NextFunction } from 'express';
import { verifyFirebaseIdToken, FirebaseVerificationErrorCode } from '../infra/firebase_token_verifier';
import { logger } from '../../../platform/logger';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      /** Resolved by `resolveAccountId` — a verified Firebase UID, or (dev/test only) a Guest Mode fallback. */
      accountId?: string;
      /** Set only when the request carried a verified Firebase ID token. */
      firebaseUser?: { uid: string; email?: string };
    }
  }
}

const VERIFICATION_ERROR_MESSAGES: Record<FirebaseVerificationErrorCode, string> = {
  EXPIRED_TOKEN: 'Firebase ID token has expired — sign in again to get a fresh one',
  REVOKED_TOKEN: 'Firebase ID token has been revoked',
  INVALID_TOKEN: 'Firebase ID token is invalid or malformed',
};

/**
 * Resolves `req.accountId` for every `/v1` request (Identity & Device
 * context, FR-ID-01). A `Authorization: Bearer <idToken>` header is verified
 * via the Firebase Admin SDK (`verifyFirebaseIdToken`) — invalid, expired, or
 * revoked tokens are rejected with 401, never silently accepted.
 *
 * Guest Mode (the legacy `x-account-id` header, used when there's no
 * Firebase session) is available ONLY outside production
 * (`NODE_ENV !== 'production'`) — it exists so local development and the
 * existing test suite don't need a live Firebase project. Production
 * requires a verified token; there is no fallback.
 */
export async function resolveAccountId(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== undefined) {
      if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({
          error: 'INVALID_AUTH_HEADER',
          message: 'Authorization header must be in the form "Bearer <idToken>"',
        });
        return;
      }
      const token = authHeader.slice('Bearer '.length).trim();
      if (!token) {
        res.status(401).json({ error: 'MISSING_TOKEN', message: 'Bearer token is empty' });
        return;
      }

      const result = await verifyFirebaseIdToken(token);
      if (!result.ok) {
        logger.warn('auth.token_rejected', { reason: result.error });
        res.status(401).json({ error: result.error, message: VERIFICATION_ERROR_MESSAGES[result.error] });
        return;
      }

      logger.debug('auth.token_verified', { accountId: result.user.uid });
      req.accountId = result.user.uid;
      req.firebaseUser = result.user;
      next();
      return;
    }

    // No Authorization header at all: Guest Mode, dev/test only.
    if (process.env.NODE_ENV !== 'production') {
      req.accountId = (req.headers['x-account-id'] as string) || 'test-account-1';
      next();
      return;
    }

    logger.warn('auth.missing_token', { path: req.path });
    res.status(401).json({
      error: 'MISSING_TOKEN',
      message: 'Authorization header with a Firebase ID token is required',
    });
  } catch (err) {
    logger.error('auth.internal_error', { message: (err as Error).message });
    res.status(500).json({ error: 'AUTH_INTERNAL_ERROR', message: 'Failed to verify authentication' });
  }
}
