/// Base type for recipe-API failures the repository can react to.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// The source is unreachable, errored, or misconfigured (e.g. missing key).
/// The repository responds by falling back to the backup source.
class ApiUnavailableException extends ApiException {
  const ApiUnavailableException(super.message);
}

/// Spoonacular returned HTTP 402 — the daily point quota is used up. Also a
/// trigger to fall back to the backup source.
class ApiQuotaExceededException extends ApiException {
  const ApiQuotaExceededException(super.message);
}
