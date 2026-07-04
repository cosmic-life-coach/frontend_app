/// The conversation's heartbeat. ChatBloc is the ONLY Bloc in the app
/// (agreed architecture boundary): it owns the message list and the
/// streaming lifecycle — user sends, chunks arrive, the assistant bubble
/// grows word by word, done/failure closes the stream.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/sse_client.dart';
import '../../../core/logging/app_logger.dart';
import '../repository/chat_repository.dart';

// ---------- Events ----------

sealed class ChatEvent {
  const ChatEvent();
}

/// The user submitted a message (typed, or a finalized voice transcript).
final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.text);
  final String text;
}

// ---------- State ----------

/// One bubble in the conversation.
class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  ChatMessage copyWith({String? text}) =>
      ChatMessage(fromUser: fromUser, text: text ?? this.text);
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;

  /// User-visible failure from the last exchange (shown as a banner).
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
    );
  }
}

// ---------- Bloc ----------

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repository) : super(const ChatState()) {
    on<ChatMessageSent>(_onMessageSent);
  }

  final ChatRepository _repository;

  /// Full lifecycle of one exchange, processed inside a single handler so
  /// events can't interleave mid-stream:
  ///   1. Append the user's bubble + an empty assistant bubble.
  ///   2. Grow the assistant bubble as SSE chunks arrive.
  ///   3. Close on done/error; transport failures become the error banner.
  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isStreaming) return; // guard double-send

    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(fromUser: true, text: text),
          const ChatMessage(fromUser: false, text: ''),
        ],
        isStreaming: true,
        error: null,
      ),
    );

    try {
      await emit.forEach<SseEvent>(
        _repository.streamChat(text),
        onData: (sse) => switch (sse) {
          SseChunk(:final text) => _appendToAssistant(text),
          SseDone(:final vectorId) => _finish(vectorId),
          SseError(:final message) => state.copyWith(
              isStreaming: false,
              error: message,
            ),
        },
      );
    } catch (e) {
      // Transport-level failure (backend down mid-stream etc.).
      appLogger.e('chat: stream failed: $e');
      emit(
        state.copyWith(
          isStreaming: false,
          error: 'Connection lost — please try again.',
        ),
      );
    }
  }

  /// Grow the last (assistant) bubble by one chunk.
  ChatState _appendToAssistant(String chunk) {
    final messages = [...state.messages];
    messages[messages.length - 1] =
        messages.last.copyWith(text: messages.last.text + chunk);
    return state.copyWith(messages: messages);
  }

  /// Stream completed; the exchange is persisted server-side.
  ChatState _finish(String vectorId) {
    appLogger.i('chat: exchange stored as $vectorId');
    return state.copyWith(isStreaming: false);
  }

  @override
  void onTransition(Transition<ChatEvent, ChatState> transition) {
    super.onTransition(transition);
    appLogger.d(
      'chat: ${transition.event.runtimeType} -> '
      '${transition.nextState.messages.length} msgs, '
      'streaming=${transition.nextState.isStreaming}',
    );
  }
}
