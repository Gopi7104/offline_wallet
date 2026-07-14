/// Clock port (ARCHITECTURE.md §11). Domain/application code depends on this
/// interface, never on DateTime.now() directly, so freshness/expiry logic is
/// deterministic in tests.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

/// Test double: advances only when told to.
class FixedClock implements Clock {
  DateTime _current;
  FixedClock(this._current);
  @override
  DateTime now() => _current;
  void set(DateTime d) => _current = d;
}
