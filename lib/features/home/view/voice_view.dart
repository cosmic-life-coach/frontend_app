/// The voice state — the design's signature moment. A breathing, glowing
/// Om orb under the greeting; below it the mic button ringed by the
/// micPulse gold ripple. While listening, the live transcript replaces
/// "TAP TO SPEAK" so the user sees their words being heard.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/cosmic_theme.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/voice_cubit.dart';

class VoiceView extends StatelessWidget {
  const VoiceView({
    super.key,
    required this.skyController,
    required this.greeting,
    required this.onChatTap,
  });

  /// Shared slow controller (starfield) reused for breathe/pulse phases.
  final AnimationController skyController;
  final String greeting;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    final voice = context.watch<VoiceCubit>().state;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OmOrb(controller: skyController, cosmic: cosmic),
        const SizedBox(height: 18),
        Text(
          greeting,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.3,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            // TODO(phase-5): replace with today's theme from
            // GET /api/v1/recommendations/daily.
            'The stars favour reflection today. Ask me anything.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: cosmic.muted),
          ),
        ),
        const SizedBox(height: 40),
        // --- Controls row: chat toggle + mic (design spacing: gap 28) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundControl(
              icon: Icons.chat_bubble_outline_rounded,
              cosmic: cosmic,
              onTap: onChatTap,
            ),
            const SizedBox(width: 28),
            _MicButton(
              cosmic: cosmic,
              listening: voice.status == VoiceStatus.listening,
              controller: skyController,
              onTap: () => context.read<VoiceCubit>().toggleListening(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // --- Status area: transcript while listening, the coach's reply
        //     streaming in after (voice mode is a full conversation now),
        //     or the idle hint. ---
        SizedBox(
          height: 110,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, chat) {
                // Priority 1: live transcript while the mic is hot.
                if (voice.status == VoiceStatus.listening) {
                  return _StatusText(
                    voice.transcript.isEmpty ? 'Listening…' : voice.transcript,
                    color: cosmic.gold,
                  );
                }
                if (voice.status == VoiceStatus.unavailable) {
                  return _StatusText(
                    'Voice input unavailable — check mic permission.',
                    color: cosmic.muted,
                  );
                }
                // Priority 2: the coach's answer to the spoken question.
                final reply = chat.messages.isNotEmpty && !chat.messages.last.fromUser
                    ? chat.messages.last.text
                    : '';
                if (chat.isStreaming || reply.isNotEmpty) {
                  return SingleChildScrollView(
                    reverse: true, // keep the newest words in view
                    child: Text(
                      chat.isStreaming ? '$reply▍' : reply,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: cosmic.assistantText,
                      ),
                    ),
                  );
                }
                // Priority 3: idle hint, exactly like the design.
                return Text(
                  'TAP TO SPEAK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: cosmic.muted,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-purpose centered status text (transcript / notices).
class _StatusText extends StatelessWidget {
  const _StatusText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, height: 1.4, color: color),
    );
  }
}

/// The big Om orb: soft gold glow that breathes (design: omBreathe/omGlow).
class _OmOrb extends StatelessWidget {
  const _OmOrb({required this.controller, required this.cosmic});

  final AnimationController controller;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final breathe = 0.5 + 0.5 * sin(2 * pi * controller.value);
        return Transform.scale(
          scale: 1 + 0.045 * breathe,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cosmic.panelBorder),
              boxShadow: [
                BoxShadow(
                  color: cosmic.gold.withValues(alpha: 0.30 + 0.25 * breathe),
                  blurRadius: 26 + 8 * breathe,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'ॐ',
              style: GoogleFonts.notoSerifDevanagari(
                fontSize: 72,
                color: cosmic.om,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 56px mic button; while listening the gold micPulse ripple expands
/// 0 → 14px and fades, exactly like the design keyframe.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.cosmic,
    required this.listening,
    required this.controller,
    required this.onTap,
  });

  final CosmicTokens cosmic;
  final bool listening;
  final AnimationController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // Faster phase than the sky so the pulse reads as ~1.5s.
        final pulse = (controller.value * 4) % 1;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3DCA0), Color(0xFFE4BE72)],
              ),
              boxShadow: listening
                  ? [
                      BoxShadow(
                        color: cosmic.gold
                            .withValues(alpha: 0.45 * (1 - pulse)),
                        spreadRadius: 14 * pulse,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: const Color(0xFF2A2110),
            ),
          ),
        );
      },
    );
  }
}

/// Small round secondary control (chat-mode toggle).
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.cosmic,
    required this.onTap,
  });

  final IconData icon;
  final CosmicTokens cosmic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cosmic.surface,
          border: Border.all(color: cosmic.border),
        ),
        child: Icon(icon, size: 20, color: cosmic.muted),
      ),
    );
  }
}
