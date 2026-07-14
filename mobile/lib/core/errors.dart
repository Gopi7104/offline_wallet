/// Domain error taxonomy (mirrors backend). Expected, named failures
/// returned via Result, not thrown (ARCHITECTURE.md §11).
abstract class DomainError {
  final String message;
  const DomainError(this.message);
  String get code;
}

/// A value object was constructed with input that violates an invariant.
class InvariantViolation extends DomainError {
  const InvariantViolation(super.message);
  @override
  String get code => 'INVARIANT_VIOLATION';
}
