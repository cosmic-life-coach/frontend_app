/// Screen 0 — Splash. The first thing the user sees: the same cosmic sky,
/// a breathing/glowing/rippling Om orb, the wordmark, and a shimmering
/// loading bar -- per the design's "Screen 00: Splash" mockup. Shown for a
/// minimum time (so it reads as a deliberate brand moment, not a flash)
/// or until Firebase Auth has resolved sign-in state, whichever is longer,
/// then hands off to the normal auth-gated redirect in app_router.dart.
///
/// NOTE: the Om ripple-ring effect here is intentionally a local copy of
/// voice_view.dart's `_OmRing` rather than a shared import -- the two were
/// built as independent, independently-reviewable changes. Worth
/// consolidating into one `core/theme` widget in a follow-up once both
/// have landed.
library;

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/cosmic_theme.dart';
import '../../../core/theme/starfield_painter.dart';

/// How long the splash stays up at minimum, regardless of how fast auth
/// resolves -- long enough to register as a brand moment, short enough
/// not to feel like a delay.
const splashMinimumDuration = Duration(milliseconds: 1800);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sky =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..repeat();
  late final AnimationController _loadBar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    final minimumElapsed = Future.delayed(splashMinimumDuration);
    // authStateChanges' first event fires as soon as Firebase has resolved
    // whether a session is already persisted -- covers both "definitely
    // signed in" and "definitely signed out", so there's no separate
    // timeout/error path needed here.
    final authResolved = FirebaseAuth.instance.authStateChanges().first;
    await Future.wait([minimumElapsed, authResolved]);
    if (!mounted) return;

    final signedIn = FirebaseAuth.instance.currentUser != null;
    context.go(signedIn ? Routes.home : Routes.auth);
  }

  @override
  void dispose() {
    _sky.dispose();
    _ring.dispose();
    _loadBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _sky,
            builder: (_, __) => CustomPaint(
              painter: StarfieldPainter(
                t: _sky.value,
                starColor: cosmic.star,
                nebula1: cosmic.nebulaA,
                nebula2: cosmic.nebulaB,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_sky, _ring]),
                  builder: (_, __) {
                    final breathe = 0.5 + 0.5 * sin(2 * pi * _sky.value);
                    return Transform.scale(
                      scale: 1 + 0.045 * breathe,
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final delay in [0.0, 1 / 3, 2 / 3])
                              _SplashOmRing(
                                progress: (_ring.value + delay) % 1.0,
                                cosmic: cosmic,
                              ),
                            Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    cosmic.gold.withValues(
                                        alpha: 0.45 + 0.25 * breathe),
                                    cosmic.gold.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              'ॐ',
                              style: GoogleFonts.notoSerifDevanagari(
                                fontSize: 96,
                                color: cosmic.om,
                                shadows: [
                                  Shadow(
                                    color: cosmic.gold.withValues(alpha: 0.75),
                                    blurRadius: 28,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  'COSMIC COACH',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 7,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'VEDIC WISDOM · DAILY GUIDANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                    color: cosmic.muted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Column(
              children: [
                SizedBox(
                  width: 110,
                  height: 3,
                  child: AnimatedBuilder(
                    animation: _loadBar,
                    builder: (_, __) => CustomPaint(
                      painter: _LoadBarPainter(
                        progress: _loadBar.value,
                        color: cosmic.gold,
                        trackColor: cosmic.muted.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'ALIGNING THE STARS…',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: cosmic.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One expanding-and-fading ring (design: `omRing` keyframe). See the note
/// atop this file re: this being a local copy of voice_view.dart's _OmRing.
class _SplashOmRing extends StatelessWidget {
  const _SplashOmRing({required this.progress, required this.cosmic});

  final double progress;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    const baseSize = 160.0;
    final scale = 0.55 + (2.1 - 0.55) * progress;
    final opacity = progress < 0.18
        ? 0.5 * (progress / 0.18)
        : 0.5 * (1 - (progress - 0.18) / (1 - 0.18));

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: baseSize,
          height: baseSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cosmic.gold, width: 1),
          ),
        ),
      ),
    );
  }
}

/// Draws the shimmering loading bar (design: `loadBar` keyframe -- a
/// gradient segment sweeping left to right and looping).
class _LoadBarPainter extends CustomPainter {
  const _LoadBarPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = trackColor;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(trackRect, track);

    // A 40%-wide gradient segment slides from just off the left edge to
    // just off the right edge, then loops.
    final segmentWidth = size.width * 0.4;
    final startX = -segmentWidth + (size.width + segmentWidth) * progress;
    final segmentRect = Rect.fromLTWH(startX, 0, segmentWidth, size.height);

    final shimmer = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
      ).createShader(segmentRect);

    canvas.save();
    canvas.clipRRect(trackRect);
    canvas.drawRect(segmentRect, shimmer);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoadBarPainter old) => old.progress != progress;
}
