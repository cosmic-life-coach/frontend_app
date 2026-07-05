/// Screen 2 — home, the heart of the app. One starfield sky hosts two
/// moods: the voice state (glowing Om orb + mic) and the chat state
/// (bubbles + input). The floating menu (screen 3) slides in over
/// everything. Voice transcripts are handed straight to the ChatBloc —
/// speaking and typing are the same conversation.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/theme/cosmic_theme.dart';
import '../../../core/theme/starfield_painter.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/voice_cubit.dart';
import '../repository/chat_repository.dart';
import 'chat_view.dart';
import 'floating_menu.dart';
import 'voice_view.dart';

/// Display name for the greeting; falls back gracefully for email accounts.
/// A provider (not a direct FirebaseAuth call in build) keeps widgets pure
/// and tests overridable.
final displayNameProvider = Provider<String>((ref) {
  try {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.trim().isEmpty) return 'Seeker';
    return name.trim().split(' ').first;
  } catch (_) {
    return 'Seeker'; // no Firebase app (tests)
  }
});

/// Time-aware greeting, like the design's "Good morning, Arjun".
String greetingForHour(int hour) => switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      _ => 'Good evening',
    };

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final isChat = useState(false); // voice state is the design's default
    final menuOpen = useState(false);
    final sky = useAnimationController(duration: const Duration(seconds: 6))
      ..repeat();

    final name = ref.watch(displayNameProvider);

    final analytics = ref.read(analyticsServiceProvider);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ChatBloc(ref.read(chatRepositoryProvider), analytics),
        ),
        BlocProvider(create: (_) => VoiceCubit(analytics: analytics)),
      ],
      child: BlocListener<VoiceCubit, VoiceState>(
        // A finalized voice transcript becomes a chat message. The user
        // STAYS in voice mode — the reply streams in under the orb
        // (mode-switching mid-interaction felt jarring; see bug report).
        listenWhen: (_, next) => next.finalTranscript != null,
        listener: (context, state) {
          context.read<ChatBloc>().add(ChatMessageSent(state.finalTranscript!));
          context.read<VoiceCubit>().consumeFinal();
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // --- The sky ---
              AnimatedBuilder(
                animation: sky,
                builder: (_, __) => CustomPaint(
                  painter: StarfieldPainter(
                    t: sky.value,
                    starColor: cosmic.star,
                    nebula1: cosmic.nebulaA,
                    nebula2: cosmic.nebulaB,
                  ),
                ),
              ),
              // --- Voice / chat states ---
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      cosmic: cosmic,
                      onMenuTap: () => menuOpen.value = true,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: isChat.value
                            ? ChatView(
                                key: const ValueKey('chat'),
                                onVoiceTap: () => isChat.value = false,
                              )
                            : VoiceView(
                                key: const ValueKey('voice'),
                                skyController: sky,
                                greeting: '${greetingForHour(DateTime.now().hour)}, $name',
                                onChatTap: () => isChat.value = true,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              // --- Screen 3: floating menu over a blurred scrim ---
              if (menuOpen.value)
                FloatingMenu(onClose: () => menuOpen.value = false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim top bar: Om mark left (brand), menu trigger right.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.cosmic, required this.onMenuTap});

  final CosmicTokens cosmic;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Text('ॐ', style: TextStyle(fontSize: 18, color: cosmic.gold)),
          const SizedBox(width: 8),
          Text(
            'Cosmic Coach',
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 1.2,
              color: cosmic.muted,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onMenuTap,
            icon: Icon(Icons.menu_rounded, color: cosmic.muted),
            tooltip: 'Menu',
          ),
        ],
      ),
    );
  }
}
