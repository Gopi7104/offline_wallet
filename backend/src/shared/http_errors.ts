import { Response } from 'express';

/**
 * Standard API error shape (production hardening §5): every error response,
 * across every bounded context, is `{error: CODE, message: string}` — never a
 * raw stack trace or internal error object. Controllers may keep constructing
 * this shape inline (many already do, and are unaffected), but new code
 * should use this helper so the shape can never drift.
 */
export function sendError(res: Response, status: number, code: string, message: string): void {
  res.status(status).json({ error: code, message });
}

/** The one shape every unexpected (non-domain) failure maps to. Never leaks `error.message` or a stack. */
export function sendInternalError(res: Response): void {
  sendError(res, 500, 'INTERNAL_ERROR', 'An error occurred');
}
