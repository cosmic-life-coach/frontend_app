/// Unit tests for ChatBloc — the streaming conversation lifecycle.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cosmic_coach/core/analytics/analytics_service.dart';
import 'package:cosmic_coach/core/api/sse_client.dart';
import 'package:cosmic_coach/features/home/bloc/chat_bloc.dart';
import 'package:cosmic_coach/features/home/repository/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockChatRepository repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockChatRepository();
    analytics = MockAnalyticsService();
  });

  blocTest<ChatBloc, ChatState>(
    'happy path: user bubble, assistant grows chunk by chunk, stream closes',
    build: () {
      when(() => repo.streamChat('hello')).thenAnswer(
        (_) => Stream.fromIterable(const [
          SseChunk('The stars '),
          SseChunk('align.'),
          SseDone('uid_daily_coach_001'),
        ]),
      );
      return ChatBloc(repo);
    },
    act: (bloc) => bloc.add(const ChatMessageSent('hello')),
    verify: (bloc) {
      expect(bloc.state.isStreaming, isFalse);
      expect(bloc.state.error, isNull);
      expect(bloc.state.messages, hasLength(2));
      expect(bloc.state.messages[0].fromUser, isTrue);
      expect(bloc.state.messages[0].text, 'hello');
      expect(bloc.state.messages[1].fromUser, isFalse);
      expect(bloc.state.messages[1].text, 'The stars align.');
    },
  );

  blocTest<ChatBloc, ChatState>(
    'backend error frame surfaces as the error banner, stream stops',
    build: () {
      when(() => repo.streamChat('hi')).thenAnswer(
        (_) => Stream.fromIterable(const [
          SseChunk('One sec'),
          SseError('Backend not connected: Gemini is unreachable.'),
        ]),
      );
      return ChatBloc(repo);
    },
    act: (bloc) => bloc.add(const ChatMessageSent('hi')),
    verify: (bloc) {
      expect(bloc.state.isStreaming, isFalse);
      expect(bloc.state.error, contains('Gemini'));
    },
  );

  blocTest<ChatBloc, ChatState>(
    'transport exception mid-stream becomes a friendly error',
    build: () {
      when(() => repo.streamChat('hi')).thenAnswer(
        (_) => Stream.error(Exception('socket closed')),
      );
      return ChatBloc(repo);
    },
    act: (bloc) => bloc.add(const ChatMessageSent('hi')),
    verify: (bloc) {
      expect(bloc.state.isStreaming, isFalse);
      expect(bloc.state.error, 'Connection lost — please try again.');
    },
  );

  blocTest<ChatBloc, ChatState>(
    'blank input is ignored entirely',
    build: () => ChatBloc(repo),
    act: (bloc) => bloc.add(const ChatMessageSent('   ')),
    expect: () => const <ChatState>[], // no state change at all
    verify: (_) => verifyNever(() => repo.streamChat(any())),
  );

  blocTest<ChatBloc, ChatState>(
    'a real message logs the chat_message_sent analytics event',
    build: () {
      when(() => repo.streamChat('hello')).thenAnswer(
        (_) => Stream.fromIterable(const [SseDone('uid_daily_coach_002')]),
      );
      return ChatBloc(repo, analytics);
    },
    setUp: () => when(() => analytics.logChatMessageSent()).thenAnswer((_) async {}),
    act: (bloc) => bloc.add(const ChatMessageSent('hello')),
    verify: (_) => verify(() => analytics.logChatMessageSent()).called(1),
  );

  blocTest<ChatBloc, ChatState>(
    'blank input never logs an analytics event',
    build: () => ChatBloc(repo, analytics),
    act: (bloc) => bloc.add(const ChatMessageSent('   ')),
    verify: (_) => verifyNever(() => analytics.logChatMessageSent()),
  );
}
