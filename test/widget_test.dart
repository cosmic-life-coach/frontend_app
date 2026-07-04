/// Smoke test replacing the `flutter create` boilerplate (which referenced
/// a nonexistent MyApp). Verifies the cosmic themes build and carry the
/// design tokens — the cheapest possible "app foundations are sane" check.
library;

import 'package:cosmic_coach/core/theme/cosmic_colors.dart';
import 'package:cosmic_coach/core/theme/cosmic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark and light themes expose the design tokens', () {
    final dark = cosmicDarkTheme().extension<CosmicTokens>();
    final light = cosmicLightTheme().extension<CosmicTokens>();

    expect(dark, isNotNull);
    expect(light, isNotNull);
    expect(dark!.gold, CosmicDark.gold);
    expect(light!.gold, CosmicLight.gold);
    expect(dark.bgGradient, isNot(light.bgGradient));
  });
}
