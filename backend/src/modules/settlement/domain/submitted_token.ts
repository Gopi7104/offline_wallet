import { Money } from '../../../shared/money';

/**
 * SubmittedToken — a token as presented by a merchant at settlement, already
 * parsed and structurally validated from the wire payload (the mobile
 * `Token.toJson()` shape: {id, denom, owner, iat, exp, status, sig}).
 *
 * Task 9 verifies structure + expiry + not-already-spent. Cryptographic
 * signature verification (issuer Ed25519, owner Ed25519) is a documented
 * prototype limitation (D3, SECURITY.md): the placeholder `bankSignature`
 * carried here is not checked. Immutable.
 */
export class SubmittedToken {
  private constructor(
    readonly tokenId: string,
    readonly denomination: Money,
    readonly ownerId: string,
    readonly expiry: Date,
    readonly bankSignature: string,
  ) {}

  isExpired(now: Date): boolean {
    return now > this.expiry;
  }

  /**
   * Parse one wire token. Returns null when the entry is malformed (missing or
   * wrong-typed fields, non-integer/negative denomination) — the caller treats
   * a null as a malformed *payload* (400), distinct from a valid-but-rejected
   * token (expired/duplicate).
   */
  static fromWire(raw: unknown): SubmittedToken | null {
    if (typeof raw !== 'object' || raw === null) return null;
    const r = raw as Record<string, unknown>;

    const tokenId = r.id;
    const denom = r.denom;
    const owner = r.owner;
    const exp = r.exp; // epoch seconds
    const sig = r.sig;

    if (typeof tokenId !== 'string' || tokenId.trim() === '') return null;
    if (typeof owner !== 'string' || owner.trim() === '') return null;
    if (typeof denom !== 'number' || !Number.isInteger(denom) || denom <= 0) return null;
    if (typeof exp !== 'number' || !Number.isFinite(exp)) return null;

    const money = Money.fromPaise(denom);
    if (!money.ok) return null;

    return new SubmittedToken(
      tokenId,
      money.value,
      owner,
      new Date(exp * 1000),
      typeof sig === 'string' ? sig : '',
    );
  }
}
