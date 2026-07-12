/// The app's telephone line to the FastAPI backend.
///
/// One configured [Dio] instance with two interceptors:
///   1. Auth — attaches a *fresh* Firebase ID token per request (tokens
///      expire hourly; caching a string is the classic mistake).
///   2. Logging — request/response timing through [appLogger]; never logs
///      the bearer token itself.
///
/// Backend errors always arrive as
///   {"success": false, "error": {"code", "message", "detail"}}
/// and are normalized into [ApiException] so the UI can showx
/// `error.message` directly.
library;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logging/app_logger.dart';
import 'api_exception.dart';

/// Base URL is injectable at build time via one of the environment config
/// files in config/ (dev/staging/prod -- see docs/environment-config.md):
///   flutter run --dart-define-from-file=config/dev.json
///
/// No hardcoded fallback on purpose -- a stale LAN IP baked into the
/// default silently pointed every uncustomized build at one developer's
/// home network. An empty value is a loud, obvious failure (every request
/// errors immediately) instead of a quiet wrong one.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Build the shared Dio client. Exposed through a Riverpod provider in
/// feature repositories; widgets never touch Dio directly.
Dio buildApiClient({FirebaseAuth? auth}) {
  if (apiBaseUrl.isEmpty) {
    appLogger.e(
      'API_BASE_URL is not set -- every request will fail. Run with '
      '--dart-define-from-file=config/dev.json (or staging/prod.json). '
      'See docs/environment-config.md.',
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 60), // SSE streams stay open
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      // --- Auth: fresh ID token on every request ---
      onRequest: (options, handler) async {
        final user = (auth ?? FirebaseAuth.instance).currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.extra['startedAt'] = DateTime.now();
        handler.next(options);
      },
      // --- Logging: timing without secrets ---
      onResponse: (response, handler) {
        final started = response.requestOptions.extra['startedAt'] as DateTime?;
        final ms = started == null
            ? '?'
            : DateTime.now().difference(started).inMilliseconds.toString();
        appLogger.i(
          '${response.requestOptions.method} ${response.requestOptions.path} '
          '-> ${response.statusCode} (${ms}ms)',
        );
        handler.next(response);
      },
      // --- Errors: normalize into ApiException ---
      onError: (error, handler) {
        final apiError = _toApiException(error);
        appLogger.e(
          '${error.requestOptions.method} ${error.requestOptions.path} '
          '-> ${apiError.code}: ${apiError.message}',
        );
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: apiError,
            response: error.response,
            type: error.type,
          ),
        );
      },
    ),
  );

  return dio;
}

/// Translate any Dio failure into the app's sealed [ApiException] vocabulary.
ApiException _toApiException(DioException error) {
  // Backend never answered: down, wrong URL, or no connectivity.
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout) {
    return const BackendUnreachable();
  }

  // Backend answered with the standard error envelope.
  final data = error.response?.data;
  if (data is Map<String, dynamic> && data['error'] is Map) {
    return ApiException.fromEnvelope(data, error.response?.statusCode);
  }

  return ServerError(
    code: 'UNKNOWN',
    message: 'Unexpected error. Please try again.',
    statusCode: error.response?.statusCode,
  );
}
