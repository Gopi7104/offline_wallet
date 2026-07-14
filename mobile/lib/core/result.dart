/// Result<T, E> — explicit success/failure without throwing for expected
/// failures. Mirrors the backend shared kernel (ARCHITECTURE.md §11).
sealed class Result<T, E> {
  const Result();
  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}
