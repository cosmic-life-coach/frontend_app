/// The listener at the observatory door. The backend streams the coach's
/// reply as Server-Sent Events; this client turns raw network bytes into a
/// typed stream of [SseEvent]s that the ChatBloc can consume.
///
/// SSE gotcha handled here: frames are delimited by a BLANK LINE (`\n\n`),
/// and network chunks can split a frame anywhere — so we buffer partial
/// data and only parse complete frames. (Splitting on single `\n` is the
/// classic bug this file exists to prevent.)
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'api_exception.dart';

/// One typed event from the chat stream.
sealed class SseEvent {
  const SseEvent();
}

/// A piece of the assistant's reply text.
final class SseChunk extends SseEvent {
  const SseChunk(this.text);
  final String text;
}

/// The stream finished; the exchange is stored under [vectorId].
final class SseDone extends SseEvent {
  const SseDone(this.vectorId);
  final String vectorId;
}

/// The backend reported a mid-stream failure.
final class SseError extends SseEvent {
  const SseError(this.message);
  final String message;
}

/// Pure transformer: buffers incoming text chunks, emits parsed events per
/// complete `\n\n`-delimited frame. Separated from Dio so it can be unit
/// tested with a plain `Stream<String>`.
Stream<SseEvent> decodeSseStream(Stream<String> textChunks) async* {
  var buffer = '';
  await for (final chunk in textChunks) {
    buffer += chunk;
    while (true) {
      final frameEnd = buffer.indexOf('\n\n');
      if (frameEnd == -1) break; // incomplete frame — wait for more bytes
      final frame = buffer.substring(0, frameEnd);
      buffer = buffer.substring(frameEnd + 2);
      final event = parseSseFrame(frame);
      if (event != null) yield event;
    }
  }
}

/// Parse a single SSE frame (`data: {...json...}`) into an [SseEvent].
/// Returns null for comments/keep-alives/unknown types.
SseEvent? parseSseFrame(String frame) {
  final dataLine = frame
      .split('\n')
      .firstWhere((l) => l.startsWith('data: '), orElse: () => '');
  if (dataLine.isEmpty) return null;

  try {
    final json = jsonDecode(dataLine.substring(6)) as Map<String, dynamic>;
    return switch (json['type']) {
      'chunk' => SseChunk(json['text']?.toString() ?? ''),
      'done' => SseDone(json['vector_id']?.toString() ?? ''),
      'error' => SseError(json['message']?.toString() ?? 'Stream failed.'),
      _ => null,
    };
  } on FormatException {
    appLogger.w('SSE: unparseable frame skipped: $frame');
    return null;
  }
}

/// Thin Dio wrapper that opens the streaming POST and hands bytes to
/// [decodeSseStream].
class SseClient {
  const SseClient(this._dio);

  final Dio _dio;

  /// POST [body] to [path] and stream typed events until `done`/`error`.
  Stream<SseEvent> post(String path, Map<String, dynamic> body) async* {
    appLogger.i('SSE open: POST $path');
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      // Interceptor already normalized this — surface as a stream error.
      final api = e.error;
      yield SseError(api is ApiException ? api.message : 'Connection failed.');
      return;
    }

    final textStream = response.data!.stream
        .map((bytes) => utf8.decode(bytes, allowMalformed: true));
    yield* decodeSseStream(textStream);
    appLogger.i('SSE closed: POST $path');
  }
}
