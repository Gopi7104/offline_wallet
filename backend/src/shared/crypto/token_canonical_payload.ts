/**
 * Canonical signing payload for a Token (ARCHITECTURE.md §4.2). Both Issuance
 * (signing, at mint) and Settlement (verification, at redemption) build the
 * exact same byte sequence from the exact same fields — the whole point of a
 * signature is that it fails the moment either side reconstructs it
 * differently, or a field is tampered with in transit.
 *
 * Deliberately NOT `JSON.stringify(obj)` on an arbitrary object: key order is
 * an implementation detail, not a contract. Field values are individually
 * JSON-escaped (handles any embedded quotes/backslashes safely) and placed in
 * a fixed template, so the output is byte-identical across engines and over
 * time.
 */
export interface TokenSigningFields {
  readonly tokenId: string;
  readonly denominationPaise: number;
  readonly ownerId: string;
  readonly issuedAtEpochSeconds: number;
  readonly expiryEpochSeconds: number;
}

export function toEpochSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000);
}

export function canonicalTokenPayload(fields: TokenSigningFields): Uint8Array {
  const canonical =
    `{"tokenId":${JSON.stringify(fields.tokenId)}` +
    `,"denominationPaise":${JSON.stringify(fields.denominationPaise)}` +
    `,"ownerId":${JSON.stringify(fields.ownerId)}` +
    `,"issuedAt":${JSON.stringify(fields.issuedAtEpochSeconds)}` +
    `,"expiresAt":${JSON.stringify(fields.expiryEpochSeconds)}}`;
  return new Uint8Array(Buffer.from(canonical, 'utf8'));
}
