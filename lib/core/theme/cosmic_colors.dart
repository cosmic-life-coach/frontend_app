/// The Cosmic Coach palette — every color in the app, extracted verbatim
/// from `design_reference/Cosmic Coach.html`. This is the single source of
/// truth: widgets never declare raw colors, they read these tokens through
/// [CosmicTheme]. Two moods exist: a deep-space dark theme (default) and a
/// dawn-sky light theme.
library;

import 'dart:ui';

/// Dark ("deep space") tokens.
abstract final class CosmicDark {
  static const bgTop = Color(0xFF0A0817);
  static const bgMid = Color(0xFF07060F);
  static const bgBottom = Color(0xFF050409);
  static const nebulaPurple = Color(0x66603AA8); // rgba(96,58,168,.4)
  static const nebulaBlue = Color(0x473A60BE); // rgba(58,96,190,.28)
  static const text = Color(0xFFF1EEFA);
  static const muted = Color(0xFF9E97BC);
  static const gold = Color(0xFFE9C77E);
  static const om = Color(0xFFF3E6C4);
  static const surface = Color(0x0DFFFFFF); // rgba(255,255,255,.05)
  static const border = Color(0x389E97BC);
  static const panel = Color(0xB8120F22);
  static const panelBorder = Color(0x2EE9C77E);
  static const assistantBubble = Color(0x0FFFFFFF);
  static const assistantText = Color(0xFFE9E5F5);
  static const scrim = Color(0x8006050F);
}

/// Light ("dawn sky") tokens.
abstract final class CosmicLight {
  static const bgTop = Color(0xFFEBF2FC);
  static const bgBottom = Color(0xFFF5EFE4);
  static const nebulaBlue = Color(0x8C96BEF0); // rgba(150,190,240,.55)
  static const nebulaLilac = Color(0x99E2D6EC); // rgba(226,214,236,.6)
  static const text = Color(0xFF2B3050);
  static const muted = Color(0xFF6E7593);
  static const gold = Color(0xFFB8933F);
  static const om = Color(0xFFC79A46);
  static const surface = Color(0xA6FFFFFF); // rgba(255,255,255,.65)
  static const border = Color(0x242C3150);
  static const panel = Color(0xB8FFFFFF);
  static const panelBorder = Color(0x7396A6BC);
  static const assistantBubble = Color(0xD9FFFFFF);
  static const assistantText = Color(0xFF333A57);
  static const scrim = Color(0x73CEDAEE);
}
