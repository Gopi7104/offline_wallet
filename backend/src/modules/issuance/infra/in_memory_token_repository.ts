import { Token } from '../domain/token';
import { TokenRepository } from '../domain/token_repository';

/**
 * InMemoryTokenRepository — adapter for Task 3.
 * Later tasks will swap this for PostgreSQL.
 */
export class InMemoryTokenRepository implements TokenRepository {
  private store = new Map<string, Token>();
  private byOwner = new Map<string, Set<string>>();

  async save(token: Token): Promise<void> {
    this.store.set(token.tokenId, token);
    if (!this.byOwner.has(token.ownerId)) {
      this.byOwner.set(token.ownerId, new Set());
    }
    this.byOwner.get(token.ownerId)!.add(token.tokenId);
  }

  async saveMany(tokens: Token[]): Promise<void> {
    for (const token of tokens) {
      await this.save(token);
    }
  }

  async findById(tokenId: string): Promise<Token | null> {
    return this.store.get(tokenId) ?? null;
  }

  async findByOwner(ownerId: string): Promise<Token[]> {
    const ids = this.byOwner.get(ownerId);
    if (!ids) return [];
    return Array.from(ids)
      .map(id => this.store.get(id))
      .filter((t): t is Token => t !== undefined);
  }

  clear(): void {
    this.store.clear();
    this.byOwner.clear();
  }
}
