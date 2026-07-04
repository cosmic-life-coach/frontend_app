/// Unit tests for the SSE decoder — the most bug-prone piece of the app's
/// networking. Frames split across chunks, multiple frames in one chunk,
/// keep-alives, and error frames must all decode correctly.
library;

import 'package:cosmic_coach/core/api/sse_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: run a list of raw text chunks through the decoder.
Future<List<SseEvent>> decode(List<String> chunks) =>
    decodeSseStream(Stream.fromIterable(chunks)).toList();

void main() {
  test('single complete frame decodes to a chunk', () async {
    final events = await decode(['data: {"type":"chunk","text":"Hello"}\n\n']);
    expect(events, hasLength(1));
    expect((events.first as SseChunk).text, 'Hello');
  });

  test('frame split across network chunks is buffered, not dropped', () async {
    final events = await decode([
      'data: {"type":"chunk","te',
      'xt":"Hel',
      'lo"}\n\ndata: {"type":"done","vector_id":"u_t_001"}\n\n',
    ]);
    expect(events, hasLength(2));
    expect((events[0] as SseChunk).text, 'Hello');
    expect((events[1] as SseDone).vectorId, 'u_t_001');
  });

  test('multiple frames in one chunk all decode in order', () async {
    final events = await decode([
      'data: {"type":"chunk","text":"a"}\n\n'
          'data: {"type":"chunk","text":"b"}\n\n'
          'data: {"type":"done","vector_id":"v1"}\n\n',
    ]);
    expect(events.map((e) => e.runtimeType).toList(),
        [SseChunk, SseChunk, SseDone]);
  });

  test('error frame surfaces as SseError with the backend message', () async {
    final events =
        await decode(['data: {"type":"error","message":"Gemini is down"}\n\n']);
    expect((events.single as SseError).message, 'Gemini is down');
  });

  test('keep-alives, comments and malformed frames are skipped', () async {
    final events = await decode([
      ': keep-alive\n\n',
      'data: not-json\n\n',
      'data: {"type":"mystery"}\n\n',
      'data: {"type":"chunk","text":"ok"}\n\n',
    ]);
    expect(events, hasLength(1));
    expect((events.single as SseChunk).text, 'ok');
  });

  test('incomplete trailing frame is never emitted', () async {
    final events = await decode(['data: {"type":"chunk","text":"cut off']);
    expect(events, isEmpty);
  });
}
