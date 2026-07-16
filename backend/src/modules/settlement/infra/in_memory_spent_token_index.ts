import { SpentTokenIndex } from '../domain/spent_token_index';

/**
 * InMemorySpentTokenIndex — adapter for Task 9. A Set gives the same
 * first-writer-wins semantics as the production UNIQUE index on
 * `spent_coins(coin_id)`: `add` is effectively insert-or-conflict.
 *
 * JavaScript's single-threaded event loop makes `tryClaim` atomic with respect
 * to other JS (no interleaving mid-method), which matches the "first upload
 * wins deterministically" property the DB constraint guarantees under
 * concurrency.
 */
export class InMemorySpentTokenIndex implements SpentTokenIndex {
  private readonly spent = new Set<string>();

  async tryClaim(tokenId: string): Promise<boolean> {
    if (this.spent.has(tokenId)) return false;
    this.spent.add(tokenId);
    return true;
  }

  async isSpent(tokenId: string): Promise<boolean> {
    return this.spent.has(tokenId);
  }

  /** Test helper. */
  clear(): void {
    this.spent.clear();
  }
}
