import { Money, PAISE_PER_RUPEE } from '../src/shared/money';
import { isOk, isErr, unwrap } from '../src/shared/result';

describe('Money (ADR-4: integer paise, INR)', () => {
  it('constructs from valid integer paise', () => {
    const r = Money.fromPaise(500);
    expect(isOk(r)).toBe(true);
    const m = unwrap(r);
    expect(m.paise).toBe(500);
    expect(m.currency).toBe('INR');
  });

  it('rejects non-integer paise (no floats in the ledger)', () => {
    expect(isErr(Money.fromPaise(1.5))).toBe(true);
  });

  it('rejects negative amounts', () => {
    expect(isErr(Money.fromPaise(-1))).toBe(true);
  });

  it('converts whole rupees to paise', () => {
    expect(unwrap(Money.fromRupees(5)).paise).toBe(5 * PAISE_PER_RUPEE);
  });

  it('adds without rounding error', () => {
    const a = unwrap(Money.fromPaise(1));
    const b = unwrap(Money.fromPaise(2));
    expect(a.add(b).paise).toBe(3);
  });

  it('subtract fails rather than going negative', () => {
    const a = unwrap(Money.fromPaise(100));
    const b = unwrap(Money.fromPaise(200));
    expect(isErr(a.subtract(b))).toBe(true);
  });

  it('formats as INR rupees', () => {
    expect(unwrap(Money.fromPaise(500)).format()).toBe('₹5.00');
  });
});
