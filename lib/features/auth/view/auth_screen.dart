/// Screen 1 — the doorway. A faithful replica of the design's auth screen:
/// the Om glyph breathing inside a gold-glowing ring over the starfield,
/// "COSMIC COACH" with its wide letterspacing, the white Google pill,
/// underline email/password fields, and the "Create an account" footer.
///
/// Navigation on success is NOT handled here — the go_router redirect
/// reacts to authStateChanges and moves the user to /home automatically.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/cosmic_theme.dart';
import '../../../core/theme/starfield_painter.dart';
import '../view_model/auth_view_model.dart';

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final email = useTextEditingController();
    final password = useTextEditingController();
    final isSignUp = useState(false);

    // One slow controller drives starfield twinkle + Om breathing.
    final sky = useAnimationController(duration: const Duration(seconds: 6))
      ..repeat();

    final auth = ref.watch(authViewModelProvider);
    final busy = auth.isLoading;

    // Firebase rejections surface as a snackbar with the friendly message.
    ref.listen(authViewModelProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- The sky ---
          AnimatedBuilder(
            animation: sky,
            builder: (_, __) => CustomPaint(
              painter: StarfieldPainter(
                t: sky.value,
                starColor: const Color(0xFFEDE7FB),
                nebula1: const Color(0x477848C4),
                nebula2: const Color(0x334068C4),
              ),
            ),
          ),
          // --- The doorway ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _OmLogo(controller: sky, cosmic: cosmic),
                    const SizedBox(height: 24),
                    Text(
                      'COSMIC COACH',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 6,
                        color: cosmic.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your daily guide, written in the stars',
                      style: TextStyle(fontSize: 14, color: cosmic.muted),
                    ),
                    const SizedBox(height: 40),
                    _GoogleButton(
                      busy: busy,
                      onPressed: () =>
                          ref.read(authViewModelProvider.notifier).signInWithGoogle(),
                    ),
                    const SizedBox(height: 28),
                    _OrDivider(cosmic: cosmic),
                    const SizedBox(height: 20),
                    _UnderlineField(
                      label: 'EMAIL',
                      hint: 'you@cosmos.app',
                      controller: email,
                      cosmic: cosmic,
                    ),
                    const SizedBox(height: 20),
                    _UnderlineField(
                      label: 'PASSWORD',
                      hint: '••••••••',
                      controller: password,
                      cosmic: cosmic,
                      obscure: true,
                      trailing: isSignUp.value
                          ? null
                          : GestureDetector(
                              onTap: busy
                                  ? null
                                  : () => ref
                                      .read(authViewModelProvider.notifier)
                                      .sendPasswordReset(email.text.trim()),
                              child: Text(
                                'Forgot?',
                                style: TextStyle(fontSize: 12, color: cosmic.gold),
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    _EnterButton(
                      busy: busy,
                      label: isSignUp.value ? 'Create account' : 'Enter',
                      cosmic: cosmic,
                      onPressed: () {
                        final vm = ref.read(authViewModelProvider.notifier);
                        isSignUp.value
                            ? vm.createAccount(email.text.trim(), password.text)
                            : vm.signInWithEmail(email.text.trim(), password.text);
                      },
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: busy ? null : () => isSignUp.value = !isSignUp.value,
                      child: Text(
                        isSignUp.value
                            ? 'Already have an account? Sign in'
                            : 'Create an account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cosmic.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Om glyph inside its glowing ring — breathing (scale 1 → 1.045) and
/// glowing brighter/softer, exactly like the design's omBreathe/omGlow.
class _OmLogo extends StatelessWidget {
  const _OmLogo({required this.controller, required this.cosmic});

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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cosmic.panelBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: cosmic.gold.withValues(alpha: 0.25 + 0.20 * breathe),
                  blurRadius: 26 + 8 * breathe,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'ॐ',
              style: GoogleFonts.notoSerifDevanagari(
                fontSize: 52,
                color: cosmic.om,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// White pill "Sign in with Google" button from the design.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2333),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sign in with Google',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// "──── or ────" separator.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.cosmic});

  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: cosmic.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(fontSize: 12, color: cosmic.muted)),
        ),
        Expanded(child: Divider(color: cosmic.border)),
      ],
    );
  }
}

/// The design's underline-style input: 11px uppercase label (letterspacing
/// 1.5) above a borderless field with only a bottom hairline.
class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.cosmic,
    this.obscure = false,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final CosmicTokens cosmic;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: cosmic.muted,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType:
              obscure ? TextInputType.text : TextInputType.emailAddress,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cosmic.muted.withValues(alpha: 0.5)),
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: cosmic.border)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: cosmic.gold)),
          ),
        ),
      ],
    );
  }
}

/// Full-width gold-outlined Enter button; shows a spinner while busy.
class _EnterButton extends StatelessWidget {
  const _EnterButton({
    required this.busy,
    required this.label,
    required this.cosmic,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final CosmicTokens cosmic;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: cosmic.gold,
          side: BorderSide(color: cosmic.gold.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cosmic.gold,
                ),
              )
            : Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
