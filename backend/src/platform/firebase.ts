import type { App } from 'firebase-admin/app';
import type { Auth } from 'firebase-admin/auth';

/**
 * Firebase Admin SDK bootstrap (ARCHITECTURE.md §5.1 `platform/firebase`;
 * FR-ID-01). This is the ONLY place that talks to the Admin SDK — the
 * Identity context's token verifier (identity/infra/firebase_token_verifier.ts)
 * calls `getFirebaseAuth()` rather than touching `firebase-admin` directly.
 *
 * The Admin SDK itself is `require`d lazily, inside `ensureInitialized()`,
 * rather than imported at module scope. This file is on the import path of
 * every `/v1` request (via auth_middleware.ts), so an eager import would
 * pull the real Admin SDK (and its transitive ESM-only deps, `jose` via
 * `jwks-rsa`, which ts-jest can't parse) into every test — including the
 * ~90 existing tests that never send an Authorization header and have
 * nothing to do with Firebase. Requiring it lazily means it's only loaded
 * the first time a request actually needs token verification.
 *
 * Credential resolution, in order:
 *   1. `FIREBASE_SERVICE_ACCOUNT_JSON` — the service account key as a JSON
 *      string (handy where mounting a file isn't convenient).
 *   2. `GOOGLE_APPLICATION_CREDENTIALS` — path to a service account key file
 *      (standard Google Cloud convention); resolved via `applicationDefault()`.
 *   3. Neither set, and NODE_ENV !== 'production' — initializes with just a
 *      project id. ID token *signature/expiry/issuer/audience* verification
 *      still works (the Admin SDK fetches Google's public signing certs over
 *      HTTPS); *revocation* checks are skipped, since those require an
 *      authenticated Identity Toolkit API call the SDK can't make without a
 *      real credential. Logged loudly; never for production.
 *   4. Neither set, and NODE_ENV === 'production' — fails fast (thrown at
 *      first use, which in `index.ts` happens before the server starts
 *      accepting traffic).
 */

let app: App | undefined;
let credentialConfigured = false;

function resolveProjectId(): string {
  return process.env.FIREBASE_PROJECT_ID || 'offline-wallet-ab2fc';
}

function ensureInitialized(): App {
  if (app) return app;

  const { initializeApp, cert, applicationDefault } =
    require('firebase-admin/app') as typeof import('firebase-admin/app');

  const projectId = resolveProjectId();
  const isProduction = process.env.NODE_ENV === 'production';

  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      app = initializeApp({ credential: cert(serviceAccount), projectId });
      credentialConfigured = true;
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      app = initializeApp({ credential: applicationDefault(), projectId });
      credentialConfigured = true;
    } else if (!isProduction) {
      // eslint-disable-next-line no-console
      console.warn(
        '[firebase] No service account configured (FIREBASE_SERVICE_ACCOUNT_JSON / ' +
          'GOOGLE_APPLICATION_CREDENTIALS). Initializing in DEVELOPMENT mode: ID token ' +
          'signature/expiry/issuer/audience verification works; revocation checks are ' +
          'skipped. Never run production like this.',
      );
      app = initializeApp({ projectId });
      credentialConfigured = false;
    } else {
      throw new Error(
        'no credentials found. Set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS.',
      );
    }
  } catch (err) {
    // Fail fast and loud — a production backend must not silently run
    // without the ability to verify who it's talking to (FR-ID-01).
    throw new Error(`Firebase Admin initialization failed: ${(err as Error).message}`);
  }

  return app;
}

export function getFirebaseAuth(): Auth {
  const { getAuth } = require('firebase-admin/auth') as typeof import('firebase-admin/auth');
  return getAuth(ensureInitialized());
}

/** Whether a real service account is configured (vs. dev-mode project-id-only init). */
export function isFirebaseCredentialConfigured(): boolean {
  ensureInitialized();
  return credentialConfigured;
}
