/// The night sky itself. Paints the design's starfield — ~40 tiny glowing
/// dots that twinkle — plus two drifting nebula blobs, behind every screen.
///
/// Stars come from a SEEDED random so the sky is identical every build
/// (no flicker on rebuild), matching the static star positions in the
/// design file. Twinkle and drift are driven by a single `t` progress
/// value supplied by an animation controller in the host widget.
library;

import 'dart:math';

import 'package:flutter/material.dart';

/// One star's fixed properties; opacity animates via the painter's `t`.
class _Star {
  const _Star(this.x, this.y, this.size, this.phase);

  final double x; // 0..1 of width
  final double y; // 0..1 of height
  final double size; // px
  final double phase; // twinkle offset so stars don't blink in unison
}

/// Generate the fixed sky once. 40 stars, like the mockup's `stars` list.
final List<_Star> _sky = () {
  final rng = Random(42); // seeded: same sky forever
  return List.generate(40, (_) {
    return _Star(
      rng.nextDouble(),
      rng.nextDouble(),
      rng.nextDouble() * 1.8 + 0.8,
      rng.nextDouble() * 2 * pi,
    );
  });
}();

/// Paints stars + nebulas. `t` loops 0→1 (from an AnimationController);
/// `starColor`/nebula colors come from the active theme's tokens.
class StarfieldPainter extends CustomPainter {
  const StarfieldPainter({
    required this.t,
    required this.starColor,
    required this.nebula1,
    required this.nebula2,
  });

  final double t;
  final Color starColor;
  final Color nebula1;
  final Color nebula2;

  @override
  void paint(Canvas canvas, Size size) {
    // --- Nebula blobs: soft radial glows drifting slowly (design: 18s loop).
    final drift = Offset(18 * t, -22 * t);
    _paintNebula(
      canvas,
      Offset(size.width * .3, size.height * .12) + drift,
      size.width * .55,
      nebula1,
    );
    _paintNebula(
      canvas,
      Offset(size.width * .88, size.height * .78) - drift,
      size.width * .45,
      nebula2,
    );

    // --- Stars: opacity oscillates .25 → 1 (design keyframe `twinkle`).
    final paint = Paint();
    for (final star in _sky) {
      final twinkle = 0.25 + 0.75 * (0.5 + 0.5 * sin(2 * pi * t + star.phase));
      paint
        ..color = starColor.withValues(alpha: twinkle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  void _paintNebula(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(StarfieldPainter old) => old.t != t;
}
