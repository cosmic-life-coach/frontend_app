/// The app's vocabulary for backend failure. Every Dio error is translated
/// into exactly one of these sealed types, so UI code can `switch` over the
/// failure and always show the backend's own `error.message` to the user.
library;

/// Base of the sealed hierarchy. `message` is always safe to display.
sealed class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  /// Build the right subtype from the backend's standard envelope:
  /// `{"success": false, "error": {"code", "message", "detail"}}`.
  factory ApiException.fromEnvelope(Map<String, dynamic> envelope, int? statusCode) {
    final error = envelope['error'] as Map<String, dynamic>? ?? const {};
    final code = error['code']?.toString() ?? 'UNKNOWN';
    final message = error['message']?.toString() ?? 'Something went wrong.';
    return switch (statusCode) {
      401 => Unauthorized(code: code, message: message),
      422 => ValidationError(code: code, message: message),
      _ => ServerError(code: code, message: message, statusCode: statusCode),
    };
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// The backend never answered: server down, wrong URL, or no connectivity.
final class BackendUnreachable extends ApiException {
  const BackendUnreachable()
      : super(
          code: 'BACKEND_UNREACHABLE',
          message: 'Backend not connected — check that the server is running.',
        );
}

/// Firebase token missing/expired — the app must re-authenticate.
final class Unauthorized extends ApiException {
  const Unauthorized({required super.code, required super.message})
      : super(statusCode: 401);
}

/// The request payload was rejected (422).
final class ValidationError extends ApiException {
  const ValidationError({required super.code, required super.message})
      : super(statusCode: 422);
}

/// Any other backend-reported failure (500, 503 with named dead service...).
final class ServerError extends ApiException {
  const ServerError({required super.code, required super.message, super.statusCode});
}
