/// Where the app gets dressed. [CosmicTokens] is a [ThemeExtension] carrying
/// every design token from the mockup, so any widget can do
/// `context.cosmic.gold` and stay pixel-faithful in both themes.
///
/// Typography follows the design file: Outfit for UI text, Noto Serif
/// Devanagari for the Om glyph and Sanskrit terms.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cosmic_colors.dart';

/// Design tokens injected into [ThemeData] as an extension.
@immutable
class CosmicTokens extends ThemeExtension<CosmicTokens> {
  const CosmicTokens({
    required this.gold,
    required this.om,
    required this.muted,
    required this.surface,
    required this.border,
    required this.panel,
    required this.panelBorder,
    required this.assistantBubble,
    required this.assistantText,
    required this.scrim,
    required this.bgGradient,
  });

  final Color gold;
  final Color om;
  final Color muted;
  final Color surface;
  final Color border;
  final Color panel;
  final Color panelBorder;
  final Color assistantBubble;
  final Color assistantText;
  final Color scrim;
  final Gradient bgGradient;

  /// Deep-space dark tokens (app default).
  static const dark = CosmicTokens(
    gold: CosmicDark.gold,
    om: CosmicDark.om,
    muted: CosmicDark.muted,
    surface: CosmicDark.surface,
    border: CosmicDark.border,
    panel: CosmicDark.panel,
    panelBorder: CosmicDark.panelBorder,
    assistantBubble: CosmicDark.assistantBubble,
    assistantText: CosmicDark.assistantText,
    scrim: CosmicDark.scrim,
    bgGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [CosmicDark.bgTop, CosmicDark.bgMid, CosmicDark.bgBottom],
      stops: [0.0, 0.55, 1.0],
    ),
  );

  /// Dawn-sky light tokens.
  static const light = CosmicTokens(
    gold: CosmicLight.gold,
    om: CosmicLight.om,
    muted: CosmicLight.muted,
    surface: CosmicLight.surface,
    border: CosmicLight.border,
    panel: CosmicLight.panel,
    panelBorder: CosmicLight.panelBorder,
    assistantBubble: CosmicLight.assistantBubble,
    assistantText: CosmicLight.assistantText,
    scrim: CosmicLight.scrim,
    bgGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [CosmicLight.bgTop, CosmicLight.bgBottom],
    ),
  );

  @override
  CosmicTokens copyWith() => this;

  @override
  CosmicTokens lerp(CosmicTokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Build the two [ThemeData] objects consumed by `app.dart`.
ThemeData cosmicDarkTheme() => _base(Brightness.dark, CosmicTokens.dark, CosmicDark.text);

ThemeData cosmicLightTheme() => _base(Brightness.light, CosmicTokens.light, CosmicLight.text);

ThemeData _base(Brightness brightness, CosmicTokens tokens, Color textColor) {
  final textTheme = GoogleFonts.outfitTextTheme().apply(
    bodyColor: textColor,
    displayColor: textColor,
  );
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: Colors.transparent, // bg gradient painted behind
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.gold,
      brightness: brightness,
    ),
    extensions: [tokens],
    useMaterial3: true,
  );
}

/// Sugar: `context.cosmic.gold` instead of `Theme.of(context).extension<...>`.
extension CosmicContext on BuildContext {
  CosmicTokens get cosmic => Theme.of(this).extension<CosmicTokens>()!;
}
