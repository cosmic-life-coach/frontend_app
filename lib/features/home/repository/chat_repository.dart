/// The messenger between the home screen and the coach. Sends the user's
/// words (typed or transcribed from voice) to POST /api/v1/chat and relays
/// the SSE event stream back to the ChatBloc.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/sse_client.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(sseClientProvider)),
);

class ChatRepository {
  const ChatRepository(this._sse);

  final SseClient _sse;

  /// One chat thread for v1; the backend uses this to build vector IDs
  /// (uid_daily_coach_001...).
  /// TODO(v2): support multiple named chat threads from a history screen.
  static const chatTitle = 'daily_coach';

  /// Stream the coach's reply to [message] as typed SSE events.
  Stream<SseEvent> streamChat(String message) =>
      _sse.post('/api/v1/chat', {'chat_title': chatTitle, 'message': message});
}
