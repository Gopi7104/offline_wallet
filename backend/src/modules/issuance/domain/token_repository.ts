import { Token } from './token';

/**
 * TokenRepository — port for token persistence.
 * Domain defines the interface; infrastructure implements it.
 */
export interface TokenRepository {
  save(token: Token): Promise<void>;
  saveMany(tokens: Token[]): Promise<void>;
  findById(tokenId: string): Promise<Token | null>;
  findByOwner(ownerId: string): Promise<Token[]>;
}
