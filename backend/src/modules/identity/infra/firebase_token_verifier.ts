import { getFirebaseAuth, isFirebaseCredentialConfigured } from '../../../platform/firebase';

export interface VerifiedFirebaseUser {
  readonly uid: string;
  readonly email?: string;
}

export type FirebaseVerificationErrorCode = 'EXPIRED_TOKEN' | 'REVOKED_TOKEN' | 'INVALID_TOKEN';

export type FirebaseVerificationResult =
  | { readonly ok: true; readonly user: VerifiedFirebaseUser }
  | { readonly ok: false; readonly error: FirebaseVerificationErrorCode };

/**
 * Verifies a Firebase ID token via the Admin SDK's `verifyIdToken` (FR-ID-01;
 * ARCHITECTURE.md §2 "the backend independently verifies Firebase ID
 * tokens"). This is the ONLY function in the codebase allowed to decide
 * whether a token is trustworthy — every caller (auth middleware,
 * /auth/session) goes through it. Never re-introduce the old
 * decode-without-verifying shortcut here.
 *
 * Revocation is checked only when a real service account is configured
 * (`isFirebaseCredentialConfigured()`) — checking revocation requires an
 * authenticated Identity Toolkit call, which a project-id-only dev-mode
 * init can't make. See platform/firebase.ts.
 */
export async function verifyFirebaseIdToken(idToken: string): Promise<FirebaseVerificationResult> {
  try {
    const decoded = await getFirebaseAuth().verifyIdToken(idToken, isFirebaseCredentialConfigured());
    const user: VerifiedFirebaseUser =
      decoded.email !== undefined ? { uid: decoded.uid, email: decoded.email } : { uid: decoded.uid };
    return { ok: true, user };
  } catch (err) {
    const code = (err as { code?: string }).code ?? '';
    if (code === 'auth/id-token-expired') return { ok: false, error: 'EXPIRED_TOKEN' };
    if (code === 'auth/id-token-revoked') return { ok: false, error: 'REVOKED_TOKEN' };
    return { ok: false, error: 'INVALID_TOKEN' };
  }
}
