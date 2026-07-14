/**
 * Clock port (ARCHITECTURE.md §11: "Clock port injected; freshness windows
 * tolerate skew; no reliance on device wall-clock for authority").
 * Domain/application code depends on this interface, never on Date directly,
 * so time-sensitive logic (nonce freshness, expiry) is deterministic in tests.
 */
export interface Clock {
  now(): Date;
}

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}

/** Test double: advances only when told to. */
export class FixedClock implements Clock {
  constructor(private current: Date) {}
  now(): Date {
    return this.current;
  }
  set(d: Date): void {
    this.current = d;
  }
}
