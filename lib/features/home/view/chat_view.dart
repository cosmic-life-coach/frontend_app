/// The chat state — bubbles over the same sky. Assistant bubbles use the
/// design's `abub` glass token on the left; the user's words sit in
/// gold-tinted bubbles on the right. The input row ends in the gold
/// gradient send orb; a mic icon flips back to voice mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../core/theme/cosmic_theme.dart';
import '../bloc/chat_bloc.dart';

class ChatView extends HookWidget {
  const ChatView({super.key, required this.onVoiceTap});

  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    final input = useTextEditingController();
    final scroll = useScrollController();

    void send() {
      context.read<ChatBloc>().add(ChatMessageSent(input.text));
      input.clear();
    }

    return BlocConsumer<ChatBloc, ChatState>(
      // Keep the newest bubble in view as chunks stream in.
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(
              scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      },
      builder: (context, state) {
        return Column(
          children: [
            // --- Error banner: the backend's own message, with retry hint ---
            if (state.error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x22D67878),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x59D67878)),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE8A0A0)),
                ),
              ),
            // --- Conversation ---
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: Text(
                        'Ask the stars anything…',
                        style: TextStyle(fontSize: 14, color: cosmic.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: state.messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: state.messages[i],
                        cosmic: cosmic,
                        // The last assistant bubble shows a caret while
                        // its text is still streaming in.
                        streaming: state.isStreaming &&
                            i == state.messages.length - 1,
                      ),
                    ),
            ),
            // --- Input row ---
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onVoiceTap,
                      icon: Icon(Icons.mic_none_rounded, color: cosmic.muted),
                      tooltip: 'Voice mode',
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cosmic.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cosmic.border),
                        ),
                        child: TextField(
                          controller: input,
                          style: const TextStyle(fontSize: 15),
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => send(),
                          decoration: InputDecoration(
                            hintText: 'Ask the stars…',
                            hintStyle: TextStyle(
                              color: cosmic.muted.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Gold gradient send orb (46px, from the design).
                    GestureDetector(
                      onTap: state.isStreaming ? null : send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF3DCA0), Color(0xFFE4BE72)],
                          ),
                        ),
                        child: state.isStreaming
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2A2110),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Color(0xFF2A2110),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One conversation bubble, styled by author.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.cosmic,
    required this.streaming,
  });

  final ChatMessage message;
  final CosmicTokens cosmic;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: fromUser
              ? cosmic.gold.withValues(alpha: 0.16)
              : cosmic.assistantBubble,
          border: Border.all(
            color: fromUser
                ? cosmic.gold.withValues(alpha: 0.35)
                : cosmic.border,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
        ),
        child: Text(
          // Streaming caret while the assistant is mid-sentence.
          streaming && !fromUser ? '${message.text}▍' : message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: fromUser
                ? Theme.of(context).textTheme.bodyLarge?.color
                : cosmic.assistantText,
          ),
        ),
      ),
    );
  }
}
