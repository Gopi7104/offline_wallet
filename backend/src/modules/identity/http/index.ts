import { Router, Request, Response } from 'express';

/**
 * Identity & Device context (ARCHITECTURE.md §4.1).
 * Owns: accounts, device bindings, one-active-device (FR-ID-04),
 * Firebase token → session (FR-ID-01).
 * Endpoints (§5.6): POST /v1/auth/session, POST /v1/devices/register.
 * Implemented in the Authentication task.
 */
export function registerIdentityRoutes(router: Router): void {
  const notImplemented = (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'identity' });

  router.post('/auth/session', notImplemented);
  router.post('/devices/register', notImplemented);
}
