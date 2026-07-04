/// The root widget — where theme, routing, and the cosmic backdrop meet.
///
/// The Scaffold backgrounds are transparent by design: [_CosmicBackground]
/// paints the design file's layered gradient behind every screen, so each
/// route floats over the same sky.
library;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/cosmic_theme.dart';

/// App-wide theme mode; the floating menu's Dark/Light toggle flips this.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

class CosmicCoachApp extends ConsumerWidget {
  const CosmicCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Cosmic Coach',
      debugShowCheckedModeBanner: false,
      theme: cosmicLightTheme(),
      darkTheme: cosmicDarkTheme(),
      themeMode: mode,
      routerConfig: buildRouter(),
      builder: (context, child) => _CosmicBackground(child: child!),
    );
  }
}

/// Paints the design's sky gradient behind every route.
class _CosmicBackground extends StatelessWidget {
  const _CosmicBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.cosmic.bgGradient),
      child: child,
    );
  }
}
