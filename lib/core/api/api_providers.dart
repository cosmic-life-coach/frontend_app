/// Riverpod wiring for the networking layer. One Dio, one SseClient,
/// shared by every repository — never constructed inside widgets.
library;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'api_client.dart';
import 'sse_client.dart';

/// The single configured Dio instance (auth + logging interceptors).
final dioProvider = Provider<Dio>((ref) => buildApiClient());

/// The SSE streaming client, built on the same Dio.
final sseClientProvider = Provider<SseClient>(
  (ref) => SseClient(ref.watch(dioProvider)),
);
